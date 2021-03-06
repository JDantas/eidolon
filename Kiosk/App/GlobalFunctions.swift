import RxSwift
import Reachability
import Moya

// Ideally a Pod. For now a file.
func delayToMainThread(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter (
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

func logPath() -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    return docs.appendingPathComponent("logger.txt")
}

let logger = Logger(destination: logPath())

private let reachabilityManager = ReachabilityManager()

// An observable that completes when the app gets online (possibly completes immediately).
func connectedToInternetOrStubbing() -> Observable<Bool> {

    let stubbing = Observable.just(APIKeys.sharedKeys.stubResponses)

    guard let online = reachabilityManager?.reach else {
        return stubbing
    }

    return [online, stubbing].combineLatestOr()
}

func responseIsOK(_ response: Response) -> Bool {
    return response.statusCode == 200
}


func detectDevelopmentEnvironment() -> Bool {
    var developmentEnvironment = false
    #if DEBUG || (arch(i386) || arch(x86_64))
        developmentEnvironment = true
    #endif
    return developmentEnvironment
}

private class ReachabilityManager {

    private let reachability: Reachability

    let _reach = ReplaySubject<Bool>.create(bufferSize: 1)
    var reach: Observable<Bool> {
        return _reach.asObservable()
    }

    init?() {
        guard let r = Reachability() else {
            return nil
        }
        self.reachability = r

        do {
            try self.reachability.startNotifier()
        } catch {
            return nil
        }

        self._reach.onNext(self.reachability.connection != .none)

        self.reachability.whenReachable = { _ in
            DispatchQueue.main.async { self._reach.onNext(true) }
        }

        self.reachability.whenUnreachable = { _ in
            DispatchQueue.main.async { self._reach.onNext(false) }
        }
    }

    deinit {
        reachability.stopNotifier()
    }
}

func bindingErrorToInterface(_ error: Swift.Error) {
    let error = "Binding error to UI: \(error)"
    #if DEBUG
        fatalError(error)
    #else
        print(error)
    #endif
}

// Applies an instance method to the instance with an unowned reference.
func applyUnowned<Type: AnyObject, Parameters, ReturnValue>(_ instance: Type, _ function: @escaping ((Type) -> (Parameters) -> ReturnValue)) -> ((Parameters) -> ReturnValue) {
    return { [unowned instance] parameters -> ReturnValue in
        return function(instance)(parameters)
    }
}
