//
//  MainViewController.swift
//  Test
//
//  Created by дилара  on 21.11.2024.
//

import UIKit

class MainViewController: UIViewController {
    private var collectionView: UICollectionView!
    private var segmentedControl: UISegmentedControl!
    private var startButton: UIButton!
    private var cancelButton: UIButton!
    private var progressView: UIProgressView!
    private var resultLabel: UILabel!
    private var activityIndicator: UIActivityIndicatorView!

    private var imageModel = ImageModel()
    private var isParallelProcessing: Bool = true
    private var currentTask: Task<Void, Never>?
    private var operationQueue: OperationQueue?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        imageModel.loadImages()
        collectionView.reloadData()
    }

    private func setupUI() {
        view.backgroundColor = .white

        segmentedControl = UISegmentedControl(items: ["Параллельно", "Последовательно"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        startButton = UIButton(type: .system)
        startButton.setTitle("Начать вычисления", for: .normal)
        startButton.addTarget(self, action: #selector(startCalculations), for: .touchUpInside)

        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Отмена", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelCalculations), for: .touchUpInside)

        progressView = UIProgressView(progressViewStyle: .bar)
        resultLabel = UILabel()
        activityIndicator = UIActivityIndicatorView(style: .large)

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(ImageCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(segmentedControl)
        view.addSubview(startButton)
        view.addSubview(cancelButton)
        view.addSubview(progressView)
        view.addSubview(resultLabel)
        view.addSubview(activityIndicator)
        view.addSubview(collectionView)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            startButton.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            cancelButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 10),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressView.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            resultLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 10),
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            collectionView.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        isParallelProcessing = sender.selectedSegmentIndex == 0
    }

    @objc private func startCalculations() {
        if isParallelProcessing {
            processImagesParallel()
        } else {
            processImagesSequentially()
        }

        currentTask = Task {
            await performLongCalculations()
        }
    }

    @objc private func cancelCalculations() {
        currentTask?.cancel()
        operationQueue?.cancelAllOperations()
        resultLabel.text = "Вычисления отменены"
    }

    private func performLongCalculations() async {
        let totalSteps = 20
        for i in 1...totalSteps {
            do {
                try await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 секунда
            } catch {
                await MainActor.run {
                    showError(message: "Ошибка выполнения задачи: \(error.localizedDescription)")
                }
                return
            }
            await MainActor.run {
                progressView.progress = Float(i) / Float(totalSteps)
                resultLabel.text = "Вычисление \(i) из \(totalSteps)"
            }
        }
        await MainActor.run {
            resultLabel.text = "Вычисления завершены"
        }
    }

    private func processImagesParallel() {
        DispatchQueue.global().async {
            let group = DispatchGroup()
            var processedImages = [UIImage]()

            for (index, image) in self.imageModel.images.enumerated() {
                group.enter()
                DispatchQueue.global().async {
                    do {
                        let processedImage = try self.imageModel.applyRandomFilter(to: image)
                        processedImages.append(processedImage)
                        DispatchQueue.main.async {
                            if let cell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ImageCollectionViewCell {
                                cell.hideLoadingIndicator()
                                cell.imageView.image = processedImage
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.showError(message: "Ошибка обработки изображения: \(error.localizedDescription)")
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.imageModel.processedImages = processedImages
                self.collectionView.reloadData()
            }
        }
    }

    private func processImagesSequentially() {
        operationQueue = OperationQueue()
        operationQueue?.maxConcurrentOperationCount = 1
        var processedImages = [UIImage]()

        for (index, image) in imageModel.images.enumerated() {
            operationQueue?.addOperation {
                do {
                    let processedImage = try self.imageModel.applyRandomFilter(to: image)
                    OperationQueue.main.addOperation {
                        processedImages.append(processedImage)
                        self.imageModel.processedImages = processedImages
                        if let cell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ImageCollectionViewCell {
                            cell.hideLoadingIndicator()
                            cell.imageView.image = processedImage
                        }
                        self.collectionView.reloadData()
                    }
                } catch {
                    OperationQueue.main.addOperation {
                        self.showError(message: "Ошибка обработки изображения: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension MainViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageModel.images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ImageCollectionViewCell
        cell.imageView.image = imageModel.images[indexPath.item]
        cell.showLoadingIndicator()
        return cell
    }
}
