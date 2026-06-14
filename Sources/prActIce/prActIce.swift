// prActIce.swift

import Foundation

@main
struct prActIce {
    static func main() {
        let practiceStore = Persistance<[question]>(filename: "practice.json")
        let wrongStore = Persistance<[question]>(filename: "wrong.json")
        let practiceList = practiceStore.read() ?? []
        let wrongList = wrongStore.read() ?? []
        for ques in practiceList {
            print(ques.question)
            if wrongList.contains(where: {$0.id == ques.id}){
                print("Wrong Question!")
            }
        }
    }
}
