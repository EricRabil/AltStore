//
//  ALTAppleAPI+Teams.swift
//  AltServer
//
//  Created by Eric Rabil on 7/2/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

import Foundation
import Combine

extension ALTAppleAPI {
    func fetchTeam(for account: ALTAccount, session: ALTAppleAPISession) -> Future<ALTTeam, Error>
    {
        Future { completionHandler in
            ALTAppleAPI.shared.fetchTeams(for: account, session: session) { (teams, error) in
                do
                {
                    let teams = try Result(teams, error).get()
                    
                    if let team = teams.first(where: { $0.type == .individual })
                    {
                        return completionHandler(.success(team))
                    }
                    else if let team = teams.first(where: { $0.type == .free })
                    {
                        return completionHandler(.success(team))
                    }
                    else if let team = teams.first
                    {
                        return completionHandler(.success(team))
                    }
                    else
                    {
                        throw InstallError.noTeam
                    }
                }
                catch
                {
                    completionHandler(.failure(error))
                }
            }
        }
    }
}
