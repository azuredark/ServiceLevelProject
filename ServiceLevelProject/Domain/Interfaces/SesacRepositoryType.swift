//
//  SesacRepositoryType.swift
//  ServiceLevelProject
//
//  Created by meng on 2022/01/24.
//

import Foundation
import Moya

protocol SesacRepositoryType: AnyObject {

    func requestUserInfo(                     // 유저정보 API
        completion: @escaping (
            Result< UserInfo,
            SesacNetworkServiceError>
        ) -> Void
    )

    func requestRegister(                      // 회원가입 API
        userRegisterInfo: UserRegisterQuery,
        completion: @escaping (
            Result< Int,
            SesacNetworkServiceError>
        ) -> Void
    )

    func requestWithdraw(                       // 회원탈퇴 API
        completion: @escaping (
            Result< Int,
            SesacNetworkServiceError>
        ) -> Void
    )

    func requestUpdateUserInfo(                 // 유저정보 업데이트 API
        userUpdateInfo: UserUpdateQuery,
        completion: @escaping (
            Result< Int,
            SesacNetworkServiceError>
        ) -> Void
    )

    func requestOnqueue(                        // 주변 새싹 위치 정보 API
        userLocationInfo: Coordinate,
        completion: @escaping (
            Result< Onqueue,
            SesacNetworkServiceError>
        ) -> Void
    )

    func requestSearchSesac(                     // 새싹 찾기 요청 API
        searchSesacQuery: SearchSesacQuery,
        completion: @escaping (
            Result< Int,
            SesacNetworkServiceError>
        ) -> Void
    )

    func requestPauseSearchSesac(                // 새싹 찾기 중단 API
        completion: @escaping (
            Result< Int,
            SesacNetworkServiceError>
        ) -> Void
    )
}
