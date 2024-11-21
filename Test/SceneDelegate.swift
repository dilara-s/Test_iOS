//
//  SceneDelegate.swift
//  Test
//
//  Created by дилара  on 21.11.2024.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let viewController = MainViewController()
        window.rootViewController = UINavigationController(rootViewController: viewController)
        self.window = window
        window.makeKeyAndVisible()
    }
    
}
