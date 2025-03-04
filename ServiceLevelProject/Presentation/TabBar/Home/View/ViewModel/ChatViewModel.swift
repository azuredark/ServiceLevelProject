//
//  ChatViewModel.swift
//  ServiceLevelProject
//
//  Created by meng on 2022/02/15.
//

import Foundation
import RxCocoa
import RxSwift

final class ChatViewModel: ViewModelType {

    private weak var coordinator: HomeCoordinator?
    private let useCase: ChatUseCase

    struct Input {
        let viewDidLoad: Observable<Void>
        let viewDidDisappear: Signal<Void>
        let backBarButtonTap: Signal<Void>
        let sendChat: Signal<String>
        let reportMenuButtonTap: Signal<Void>
        let cancelMenuButtonTap: Signal<Void>
        let reviewMenuButtonTap: Signal<Void>
    }
    struct Output {
        let showToastAction: Signal<String>
        let myState: Signal<MyQueueState>
        let chatList: Driver<[Chat]>
        let resetTextViewAction: Signal<Void>
        let navigationTitle: Driver<String>
        let dismissDetailMenu: Signal<Void>
        let bottomScrollAction: Signal<Int>
    }
    var disposeBag = DisposeBag()

    private let chatList = BehaviorRelay<[Chat]>(value: [])
    private let showToastAction = PublishRelay<String>()
    private let myState = PublishRelay<MyQueueState>()
    private let resetTextViewAction = PublishRelay<Void>()
    private let navigationTitle = BehaviorRelay<String>(value: "...")
    private let dismissDetailMenu = PublishRelay<Void>()
    private let bottomScrollAction = PublishRelay<Int>()

    init(coordinator: HomeCoordinator?, useCase: ChatUseCase) {
        self.coordinator = coordinator
        self.useCase = useCase
    }

    func transform(input: Input) -> Output {
        input.viewDidLoad
            .subscribe(onNext: { [weak self] in
                self?.useCase.requestMyQueueState()
            })
            .disposed(by: disposeBag)

        input.sendChat
            .emit(onNext: { [weak self] text in
                print(text)
                self?.useCase.requestSendChat(chatQuery: ChatQuery(text: text))
            })
            .disposed(by: disposeBag)

        input.viewDidDisappear
            .emit(onNext: { [weak self] in
                self?.useCase.disconnectSocket()
            })
            .disposed(by: disposeBag)

        input.backBarButtonTap
            .emit(onNext: { [weak self] in
                self?.coordinator?.popToRootViewController()
            })
            .disposed(by: disposeBag)

        input.cancelMenuButtonTap
            .emit(onNext: { [weak self] in
                self?.dismissDetailMenu.accept(())
                let alert = AlertView.init(
                    title: "약속을 취소하시겠습니까?",
                    message: "약속을 취소하시면 패널티가 부과됩니다.",
                    buttonStyle: .confirmAndCancel) { [weak self] in
                        self?.requestDodge()
                    }
                alert.showAlert()
            })
            .disposed(by: disposeBag)

        input.reviewMenuButtonTap
            .emit(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismissDetailMenu.accept(())
                let popup = PopupView.init(style: .review) { [weak self] reputation, text in
                    self?.requestWriteReview(reputation: reputation, text: text)
                }
                popup.showPopup()
            })
            .disposed(by: disposeBag)

        input.reportMenuButtonTap
            .emit(onNext: { [weak self] in
                guard let self = self else { return }
                self.dismissDetailMenu.accept(())
                let popup = PopupView.init(style: .report) { [weak self] report, text in
                    self?.requestReport(report: report, comment: text)
                }
                popup.showPopup()
            })
            .disposed(by: disposeBag)

        self.useCase.successLoadRealmChat
            .asSignal()
            .emit(to: chatList)
            .disposed(by: disposeBag)

        self.useCase.successLoadRealmChat
            .asSignal()
            .emit(onNext: { [weak self] list in
                guard let self = self else { return }
                let lastDate = list.last?.createdAt.dateToString() ?? "2000-01-01T00:00:00.000Z"
                print("마지막날짜 -->", lastDate)
                self.useCase.requestChat(dateString: lastDate)
            })
            .disposed(by: disposeBag)

        self.useCase.successRequestChatList
            .asSignal()
            .emit(onNext: { [weak self] chats in
                guard let self = self else { return }
                let list = self.chatList.value + chats
                self.chatList.accept(list)
                self.bottomScrollAction.accept(list.count - 1)
                self.useCase.socketChatInfo()
                self.useCase.connectSocket()
            })
            .disposed(by: disposeBag)

        self.useCase.successRequestMyQueueState
            .asSignal()
            .emit(onNext: { [weak self] state in
                guard let self = self else { return }
                self.navigationTitle.accept(state.matchedNick)
                if state.dodged == 1 || state.reviewed == 1 {
                    self.showToastAction.accept("약속이 종료되어 채팅을 보낼 수 없습니다")
                } else if state.matched == 1 {
                    self.useCase.loadChat()
                    self.myState.accept(state)
                }
            })
            .disposed(by: disposeBag)

        self.useCase.sendChat
            .asSignal()
            .emit(onNext: { [weak self] chat in
                guard let self = self else { return }
                var list = self.chatList.value
                list.append(chat)
                self.chatList.accept(list)
                self.bottomScrollAction.accept(list.count - 1)
                self.resetTextViewAction.accept(())
            })
            .disposed(by: disposeBag)

        self.useCase.receivedChat
            .asSignal()
            .emit(onNext: { [weak self] chat in
                guard let self = self else { return }
                var list = self.chatList.value
                list.append(chat)
                self.chatList.accept(list)
            })
            .disposed(by: disposeBag)

        self.useCase.sendChatErrorSignal
            .asSignal()
            .emit(onNext: { [weak self] error in
                guard let self = self else { return }
                switch error {
                case .duplicatedError:
                    self.showToastAction.accept("약속이 종료되어 채팅을 보낼 수 없습니다")
                default :
                    return
                }
            })
            .disposed(by: disposeBag)

        self.useCase.successRequestDodge
            .asSignal()
            .emit(onNext: { [weak self] in
                self?.coordinator?.popToRootViewController(message: "채팅을 종료합니다.")
            })
            .disposed(by: disposeBag)

        self.useCase.successReview
            .asSignal()
            .emit(onNext: { [weak self] in
                self?.coordinator?.popToRootViewController(message: "리뷰가 작성되었습니다.")
            })
            .disposed(by: disposeBag)

        self.useCase.successReport
            .asSignal()
            .emit(onNext: { [weak self] in
                self?.showToastAction.accept("신고가 완료되었습니다.")
            })
            .disposed(by: disposeBag)

        return Output(
            showToastAction: showToastAction.asSignal(),
            myState: myState.asSignal(),
            chatList: chatList.asDriver(),
            resetTextViewAction: resetTextViewAction.asSignal(),
            navigationTitle: navigationTitle.asDriver(),
            dismissDetailMenu: dismissDetailMenu.asSignal(),
            bottomScrollAction: bottomScrollAction.asSignal()
        )
    }
}

extension ChatViewModel {

    private func requestDodge() {
        self.useCase.requestDodge()
    }

    private func requestWriteReview(reputation: [Int], text: String) {
        self.useCase.reqeustWriteReview(reputation: reputation, review: text)
    }

    private func requestReport(report: [Int], comment text: String) {
        self.useCase.requestReport(report: report, comment: text)
    }
}
