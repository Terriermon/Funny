import Foundation

func test() {
    let request = URLRequest(url: URL(string: "")!)
    URLSession.shared.retryCount(3).dataTask(with: request) { data, response, error in }.resume()
}

extension URLSession {
    func retryCount(_ retryCount: Int, retryCondition: ((Data?, URLResponse?, Error?) -> Bool)? = nil) -> RetrySession {
       RetrySession(retryCount: retryCount, session: self, retryCondition: retryCondition)
    }
}

class RetrySession {
    let retryCount: Int
    var delay: Int
    let session: URLSession
    let retryCondition: ((Data?, URLResponse?, Error?) -> Bool)?
    
    private var currentRequestIndex: Int = 0
    
    private var lastestData: Data?
    private var lastestResponse: URLResponse?
    private var lastestError: Error?
    
    init(retryCount: Int, session: URLSession, delay: Int = 0, retryCondition: ((Data?, URLResponse?, Error?) -> Bool)? = nil) {
        self.retryCount = retryCount
        self.session = session
        self.delay = delay
        self.retryCondition = retryCondition
    }
    
    func dataTask(with urlRequest: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        request(urlRequest: urlRequest, completionHandler: completionHandler)
    }
    
    private func retry(request urlRequest: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard currentRequestIndex < retryCount else {
            currentRequestIndex = 0;
            completionHandler(lastestData, lastestResponse, lastestError)
            return
        }
        currentRequestIndex += 1
        
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(delay)) {
            self.request(urlRequest: urlRequest, completionHandler: completionHandler).resume()
        }
    }
    
    private func request(urlRequest: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
       session.dataTask(with: urlRequest) { [weak self] data, response, error in
           guard let self else { return }
           
           self.lastestData = data
           self.lastestResponse = response
           self.lastestError = error
           
            guard error == nil else {
                self.retry(request: urlRequest, completionHandler: completionHandler)
                return
            }
           
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                self.retry(request: urlRequest, completionHandler: completionHandler)
                return
            }
           
           if let retryCondition = self.retryCondition, retryCondition(data, response, error) {
               self.retry(request: urlRequest, completionHandler: completionHandler)
               return
           }
           
            completionHandler(data, response, error)
        }
    }
}

