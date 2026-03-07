import Foundation

// MARK: - AIメニュータイプ

enum AIMenuType: String {
    case consultation = "consultation"
    case summary = "summary"
    case sns = "sns"
}

// MARK: - AIレスポンス

struct AIResponse: Decodable {
    let result: String
    let referencedBooks: [String]
}

// MARK: - AIリクエスト用書籍データ

struct AIBookData {
    let title: String
    let author: String
    let memos: [String]

    var asDictionary: [String: Any] {
        ["title": title, "author": author, "memos": memos]
    }
}

// MARK: - AIサービスエラー

enum AIServiceError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "無効なレスポンスを受信しました"
        case .serverError(let code):
            return "サーバーエラー（\(code)）"
        case .timeout:
            return "タイムアウトしました"
        }
    }
}

// MARK: - AIService

struct AIService {

    private static let endpointURL = URL(string: "https://it-master.jp/api/biblion/ai")!
    private static let timeoutSeconds: TimeInterval = 30

    /// AI APIを呼び出す
    /// - チケット消費はこのメソッドの外（呼び出し元）で、成功後に行う
    func execute(
        menuType: AIMenuType,
        userInput: String,
        bookData: [AIBookData]
    ) async throws -> AIResponse {

        var request = URLRequest(url: AIService.endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AIService.timeoutSeconds

        let body: [String: Any] = [
            "menuType": menuType.rawValue,
            "userInput": userInput,
            "bookData": bookData.map { $0.asDictionary }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AIServiceError.timeout
        } catch {
            throw AIServiceError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AIServiceError.serverError(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(AIResponse.self, from: data)
            return decoded
        } catch {
            throw AIServiceError.invalidResponse
        }
    }
}
