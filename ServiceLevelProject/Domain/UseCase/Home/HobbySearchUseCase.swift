//
//  HobbySearchUseCase.swift
//  ServiceLevelProject
//
//  Created by meng on 2022/02/11.
//

import Foundation
import RxSwift
import RxRelay

final class HobbySearchUseCase {

    private let userRepository: UserRepositoryType
    private let fireBaseRepository: FirbaseRepositoryType
    private let sesacRepository: SesacRepositoryType

    var successRequestMyQueueState = PublishRelay<MyQueueState>()
    var successRequestSesacFriend = PublishRelay<Void>()
    var successAcceptSesacFriend = PublishRelay<Void>()
    var successPauseSearchSesac = PublishRelay<Void>()
    var successOnqueueSignal = PublishRelay<Onqueue>()
    var alreadyMatchedErrorSignal = PublishRelay<Void>()
    var unKnownErrorSignal = PublishRelay<Void>()

    init(
        userRepository: UserRepositoryType,
        fireBaseRepository: FirbaseRepositoryType,
        sesacRepository: SesacRepositoryType
    ) {
        self.userRepository = userRepository
        self.fireBaseRepository = fireBaseRepository
        self.sesacRepository = sesacRepository
    }

    func requestOnqueue(coordinate: Coordinate) {
        self.sesacRepository.requestOnqueue(userLocationInfo: coordinate) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let onqueue):
                self.successOnqueueSignal.accept(onqueue)
            case .failure(let error):
                switch error {
                case .inValidIDTokenError:
                    self.requestIDToken {
                        self.requestOnqueue(coordinate: coordinate)
                    }
                default:
                    self.unKnownErrorSignal.accept(())
                }
            }
        }
    }

    func requestMyQueueState() {
        self.sesacRepository.requestMyQueueState { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let myQueue):
                self.successRequestMyQueueState.accept(myQueue)
            case .failure(let error):
                switch error {
                case .inValidIDTokenError:
                    self.requestIDToken {
                        self.requestMyQueueState()
                    }
                default:
                    self.unKnownErrorSignal.accept(())
                }
            }
        }
    }

    func requestPauseSearchSesac() {
        self.sesacRepository.requestPauseSearchSesac { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let code):
                print(code)
                self.saveMatchStatus(status: .general)
                self.successPauseSearchSesac.accept(())
            case .failure(let error):
                switch error {
                case .duplicatedError:
                    self.alreadyMatchedErrorSignal.accept(())
                case .inValidIDTokenError:
                    self.requestIDToken {
                        self.requestPauseSearchSesac()
                    }
                default:
                    self.unKnownErrorSignal.accept(())
                }
            }
        }
    }

    func requestSesacFriend(userID: String) {
        let sesacFriendQuery = SesacFriendQuery(userID: userID)
        self.sesacRepository.requestSesacFriend(sesacFriendQuery: sesacFriendQuery) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let code):
                print(code)
                self.successRequestSesacFriend.accept(())
            case .failure(let error):
                switch error {
                case .inValidIDTokenError:
                    self.requestIDToken {
                        self.requestSesacFriend(userID: userID)
                    }
                default:
                    self.unKnownErrorSignal.accept(())
                }
            }
        }
    }

    func requestAcceptSesacFriend(userID: String) {
        let sesacFriendQuery = SesacFriendQuery(userID: userID)
        self.sesacRepository.requestAcceptSesacFriend(sesacFriendQuery: sesacFriendQuery) { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(_):
                self.saveMatchStatus(status: .matched)
                self.successAcceptSesacFriend.accept(())
            case .failure(let error):
                print(error)
                switch error {
                case .inValidIDTokenError:
                    self.requestIDToken {
                        self.requestAcceptSesacFriend(userID: userID)
                    }
                default:
                    self.unKnownErrorSignal.accept(())
                }
            }
        }
    }

    private func requestIDToken(completion: @escaping () -> Void) {
        fireBaseRepository.requestIdtoken { [weak self] response in
            guard let self = self else { return }
            switch response {
            case .success(let idToken):
                print("재발급 성공--> \(idToken)")
                self.saveIdTokenInfo(idToken: idToken)
                completion()
            case .failure(let error):
                print(error.description)
                self.logoutUserInfo()
                self.unKnownErrorSignal.accept(())
            }
        }
    }

    func saveMatchStatus(status: MatchStatus) {
        self.userRepository.saveMatchStatus(status: status)
    }

    private func saveIdTokenInfo(idToken: String) {
        self.userRepository.saveIdTokenInfo(idToken: idToken)
    }

    private func logoutUserInfo() {
        self.userRepository.logoutUserInfo()
    }
}
