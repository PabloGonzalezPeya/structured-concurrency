import SwiftUI

/*
- Concurrencia: Permitir multiples piezas de código ejecutarse al mismo tiempo.
- Concurrencia Estructurada: Es un paradigma de programación que apunta a mejorar la claridad, calidad y tiempo de desarrollo de un programa al usar un enfoque estructurado para la concurrencia. Es más facil de razonar porque los métodos son ejecutados linealmente sin ir de atras para adelante como sucedería con closures.

 Conceptos clave básicos:

 Task - Una Task nos permite crear un ambiente concurrente para un método no concurrente, invocar métodos usando async/await.
 Al trabajar con Tasks la primera vez, puedes reconocer familiaridades entre dispatch queues y tasks. Ambas permiten despachar trabajo a otro hilo con una prioridad específica. De todas formas, las tasks son diferentes en cuanto a que eliminan la verbosidad de las dispatch queues.

Async/Await - Await esta esperando una respuesta de su amigo Async :) Cuando invoco una función async lo hago con await en el contexto de una Task o dentro de una función Async.
 */

@available(iOS 16.0, *)
struct ContentView: View {
    @State var image: UIImage?
    @State var textValue: String?

    var body: some View {
        VStack(spacing: 20) {
            Button("Perform Long running operation") {
                handleLongRunningOperationTap()
            }

            Button("Tap me for fun numbers") {
                textValue = String(Int.random(in: 1...1000))
            }

            if let textValue = textValue {
                Text(textValue)
            }

            Button("Tap to get new image") {
                Task {
                    do {
                        let remoteImage = try await fetchImage()
                        image = remoteImage
                    } catch let error {
                        print(error)
                    }
                }
            }

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .scaledToFit()
            }

            Button("Run in parallel or sequentially") {
                // Sequentially
                Task {
                    let firstOp = await printIndex(index:1)
                    let secondOp = await printIndex(index:2)
                    let thirdOp = await printIndex(index:3)
                    let results =  [firstOp, secondOp, thirdOp]
                    print(results)
                }

                // Parallel
                Task {
                    async let firstOp = printIndex(index:1)
                    async let secondOp = printIndex(index:2)
                    async let thirdOp = printIndex(index:3)
                    let results = await [firstOp, secondOp, thirdOp]
                    print(results)
                }

                // Paralell with TaskGroup. Also has withThrowingTaskGroup variant
                Task {
                    let values = await withTaskGroup(of: String.self, returning: [String].self, body: { taskGroup in
                        for index in 1...10 {
                            taskGroup.addTask(operation: { await printIndex(index: index)})
                        }

                        var finalResult = [String]()
                        for await result in taskGroup {
                            finalResult.append(result)
                        }
                        return finalResult
                    })
                    print(values)
                }
            }

            Button("Test Task Thread") {
                /*
                 Una task creada con Task.init hereda la prioridad, valores de la task local, y contexto de actor del que la invoca.
                 */
                Task() {
                    print("I inherit main actor")
                    await noMainFunction()
                    await mainFunction()
                    await noMainFunction()
                    let test = MyTestClass()
                    test.textActorContext()
                    print("finished")
                }

                /*
                 Una task creada con Task.detached no es parte de la jerarquía de concurrencia estructurada. Son independientes del contexto del padre y no heredan su prioridad. Son utiles cuando precisas realizas una tarea que es completamente independiente de la tarea padre y no necesita comunicarse con ella o devolverle algún valor.
                 */
//                Task.detached {
//                    print("I have no inheritance, global queue equivalent")
//                    await noMainFunction()
//                    await mainFunction()
//                    await noMainFunction()
//                }
            }

            Button("Actor") {
                let feeder = ChickenFeeder()
                Task {
                    async let a: () = feeder.chickenStartsEating()
                    async let b: () = feeder.chickenStopsEating()
                    async let c: () = feeder.chickenStartsEating()
                    async let d: () = feeder.chickenStopsEating()
                    async let e: () = feeder.chickenStartsEating()
                    async let f: () = feeder.chickenStopsEating()

                    _ = await [a, b, c, d, e, f]
                }
            }

            Button("Factors") {
                Task(priority: .background) {
                    let factors = await factors(for:10000000)
                    print("background")
                    print(factors)
                }

//                Task(priority: .userInitiated) {
//                    let factors = await factorsYield(for:10000000)
//                    print("userInitiated")
//                    print(factors)
//                }
            }
        }
    }
}

class MyTestClass {
    func textActorContext() {
        Task {
            await sayHi()
            await sayHi()
            await sayHi()
            print("Finished")
        }
    }

    func sayHi() async {
        print("Hello world")
    }
}

@available(iOS 16.0, *)
extension ContentView {
    @MainActor func mainFunction() async {
        print("mainFunction")
    }

    func noMainFunction() async {
        print("noMainFunction")
    }

    func handleLongRunningOperationTap() {
        let longTask = Task<Void, Never> {
            do {
                try await performLongRunningTask()
                print("Done from long running task")
            } catch let error {
                if error is CancellationError {
                    print("Task cancelled")
                } else {
                    print(error)
                }
            }
        }
        longTask.cancel()
    }

    func performLongRunningTask() async throws {
        try await Task.sleep(for: .seconds(5))
    }

    func printIndex(index: Int) async -> String {
        print(index)
        return String(index)
    }

    func fetchImage(completion: @escaping (Result<UIImage, Error>) -> Void) {
        let imageURL = URL(string: "https://source.unsplash.com/random")!
        print("Starting network request...")
        let dataTask = URLSession.shared.dataTask(with: URLRequest(url: imageURL)) { data, _, error in
            if let receivederror = error {
                completion(.failure(receivederror))
            }
            if let imageData = data {
                completion(.success(UIImage(data: imageData)!))
            }
        }
        dataTask.resume()
    }

    func fetchImage() async throws -> UIImage {
        try await withCheckedThrowingContinuation({ continuation in
            fetchImage { result in
                switch result {
                case .success(let remoteImage):
                    continuation.resume(returning: remoteImage)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        })
    }

    /*
     Cuando trabajas en escribir una capa de conversión para transformar tu código basado en callback, a código que soporta async/await en Swift, te vas a encontrar normalmente usando continuations. Una continuation es un closure que llamas con el resultado de tu taréa asíncrona. Puedes pasarle lo que obtengas de tu taréa, un objeto que conforme a Error o un Result.

     Notarás que hay 4 métodos que puedes usar para crear una continuation:

     withCheckedThrowingContinuation
     withCheckedContinuation
     withUnsafeThrowingContinuation
     withUnsafeContinuation

     Lo más relevante pareciera ser que puedes optar entre una Checked o Unsafe. Antes veamos algunas reglas que debemos seguir al usar una continuation
     - Solo debes llamar el resume de una continuation una sola vez. Hacerlo más de una vez es un error del desarrollador y puede generar comportamiento inesperado.
     - Debes retener la coninuación para resumir con un valor o un error. El no hacerlo hace que tu código quede esperando por siempre.

     Si fallas en hacer alguno de estos puntos, es un error del desarrollador. Por suerte la checked continuation realiza algunas verificaciones para asegurarlo.
     Una unsafe funciona con las mismas reglas que una checked pero no chequea que adieras a dichas reglas.
     Apple aparentemente recomienda usar unchecked luego de validar con checked por un tema de overhead pero no tengo claras las repercuciones de ese overhead.

     https://developer.apple.com/documentation/swift/unsafecontinuation#

     Donny Walls prefiere mantenerlo.

     Is it important that you get rid of this overhead? No, in by far the most situations I highly doubt that the overhead of checked continuations is noticeable in your apps. That said, if you do find a reason to get rid of your checked continuation in favor of an unsafe one, it’s important that you understand what an unsafe continuation does exactly.
     */

    func factors(for number: Int) async -> [Int] {
        var result = [Int]()

        for check in 1...number {
            if number.isMultiple(of: check) {
                result.append(check)
                print(Thread.current.description)
            }
        }

        return result
    }

    func factorsYield(for number: Int) async -> [Int] {
        var result = [Int]()

        for check in 1...number {
            if number.isMultiple(of: check) {
                result.append(check)
                /*
                 Piensa en llamar a Task.yield() como el equivalente a llamar un Task.doNothing(), lo cual le da a Swift la oportunidad de ajustar la ejecución de sus Tasks sin crear ningun nuevo trabajo real, dandole la oportunidad al hilo de hacer otras cosas.
                 */
                await Task.yield()
                print(Thread.current.description)
            }
        }

        return result
    }

}
