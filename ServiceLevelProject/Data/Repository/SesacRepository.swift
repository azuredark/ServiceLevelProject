//
//  SesacRepository.swift
//  ServiceLevelProject
//
//  Created by meng on 2022/01/23.
//

import Foundation
import Moya

enum SesacNetworkServiceError: Int, Error {

    case duplicatedError = 201
    case inValidInputBodyError = 202
    case inValidIDTokenError = 401
    case alreadyWithdrawn = 406
    case internalServerError = 500
    case internalClientError = 501
    case unknown

    var description: String { self.errorDescription }
}

extension SesacNetworkServiceError {

    var errorDescription: String {
        switch self {
        case .duplicatedError: return "201:DUPLICATE_ERROR"
        case .inValidInputBodyError: return "202:INVALID_INPUT_BODY_ERROR"
        case .inValidIDTokenError: return "401:INVALID_FCM_TOKEN_ERROR"
        case .internalServerError: return "500:INTERNAL_SERVER_ERROR"
        case .internalClientError: return "501:INTERNAL_CLIENT_ERROR"
        default: return "UN_KNOWN_ERROR"
        }
    }
}

final class SesacRepository: SesacRepositoryType {

    let provider: MoyaProvider<SLPTarget>
    init() { provider = MoyaProvider<SLPTarget>() }
}

extension SesacRepository {

    func requestUserInfo(completion: @escaping (Result<UserInfo, SesacNetworkServiceError>) -> Void) {
        provider.request(.getUserInfo) { result in
            switch result {
            case .success(let response):
                let data = try? JSONDecoder().decode(UserInfoResponseDTO.self, from: response.data)
                completion(.success(data!.toDomain()))
            case .failure(let error):
                completion(.failure(SesacNetworkServiceError(rawValue: error.response!.statusCode) ?? .unknown))
            }
        }
    }

    func requestRegister(userRegisterInfo: UserRegisterInfo, completion: @escaping (Result<Int, SesacNetworkServiceError>) -> Void ) {
        let requestDTO = UserRegisterInfoRequestDTO(userRegisterInfo: userRegisterInfo)
        provider.request(.register(parameters: requestDTO.toDictionary)) { result in
            self.process(result: result,completion: completion)
        }
    }

    func requestWithdraw(completion: @escaping (Result<Int, SesacNetworkServiceError>) -> Void ) {
        provider.request(.withdraw) { result in
            self.process(result: result,completion: completion)
        }
    }
}

extension SesacRepository {

    private func process<T: Codable, E>(
        type: T.Type,
        result: Result<Response, MoyaError>,
        completion: @escaping (Result<E, SesacNetworkServiceError>) -> Void
    ) {
        switch result {
        case .success(let response):
            let data = try? JSONDecoder().decode(type, from: response.data)
            completion(.success(data as! E))
        case .failure(let error):
            completion(.failure(SesacNetworkServiceError(rawValue: error.response!.statusCode) ?? .unknown))
        }
    }

    private func process(
        result: Result<Response, MoyaError>,
        completion: @escaping (Result<Int, SesacNetworkServiceError>) -> Void
    ) {
        switch result {
        case .success(let response):
            completion(.success(response.statusCode))
        case .failure(let error):
            completion(.failure(SesacNetworkServiceError(rawValue: error.response!.statusCode) ?? .unknown))
        }
    }
}
