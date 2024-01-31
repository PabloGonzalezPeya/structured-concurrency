//
//  StrongReference.swift
//  AppPlaygroundAsyncAwait
//
//  Created by Pablo Gonzalez on 31/1/24.
//

import SwiftUI

@available(iOS 16.0, *)
class DataManager {
    func getText(duration: Int = 3) async -> String {
        try? await Task.sleep(for: .seconds(duration))
        print(Thread.current.description)
        return "Hello world from data manager"
    }
}

@available(iOS 16.0, *)
class ViewModel: ObservableObject {
    @Published private(set) var text: String = "Hola Mundo!"
    var dataManager = DataManager()

    func changeText() {
        text = "My new Hello World"
    }

    func changeTextFromDataManager() {
        Task {
            print(Thread.current.description)
            let dataManagerText = await dataManager.getText()
            text = dataManagerText
        }
    }

    func validateReference() {
        let dummy = DummyStrongClass()
        dummy.performTask()
    }
}

@available(iOS 16.0, *)
struct StrongReference: View {
    @StateObject var viewModel = ViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Button("Change Text") {
                viewModel.changeText()
            }
            Button("Change Text From Data Manager") {
                viewModel.changeTextFromDataManager()
            }
            Text(viewModel.text)
            Button("Validate Reference") {
                viewModel.validateReference()
            }
        }

    }
}

@available(iOS 16.0, *)
struct StrongReference_Previews: PreviewProvider {
    static var previews: some View {
        StrongReference()
    }
}

@available(iOS 16.0, *)
class DummyStrongClass {
    var dataManager = DataManager()
    var text = ""

    func performTask() {
        Task {
            let newText = await dataManager.getText(duration: 6)
            text = newText
        }
    }

    deinit {
        print("Dummy is gone")
    }
}
