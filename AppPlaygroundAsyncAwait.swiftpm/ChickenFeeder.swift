//
//  ChickenFeeder.swift
//  AppPlaygroundAsyncAwait
//
//  Created by Pablo Gonzalez on 24/1/24.
//

import Foundation

actor ChickenFeeder {
    let food = "worms"
    var numberOfEatingChickens: Int = 0

    func chickenStartsEating() {
        numberOfEatingChickens += 1
    }

    func chickenStopsEating() {
        guard numberOfEatingChickens > 0 else {
            print("There are no chickens")
            return
        }
        numberOfEatingChickens -= 1
    }
}
