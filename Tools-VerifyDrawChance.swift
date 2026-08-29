import Foundation
// 8巡目に聴牌、両面待ち計8枚。見えていない牌は 95 - 8 = 87枚。
// そこから5回ツモったときに当たりを引く確率を、
// (1)式で計算した値 と (2)実際に山を引くシミュレーション で突き合わせる。
let unseen = 87, waits = 8, draws = 5

// (1) 超幾何分布の式
var miss = 1.0
for i in 0..<draws { miss *= Double(unseen - waits - i) / Double(unseen - i) }
let formula = 1 - miss

// (2) 山を作って実際に引く
var state: UInt64 = 20260829
func rnd(_ n: Int) -> Int {
    state = state &* 6364136223846793005 &+ 1442695040888963407
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return Int((z ^ (z >> 31)) % UInt64(n))
}
let trials = 2_000_000
var hits = 0
for _ in 0..<trials {
    var pile = [Bool](repeating: false, count: unseen)
    for i in 0..<waits { pile[i] = true }
    var found = false
    for j in 0..<draws {
        let k = j + rnd(unseen - j)
        pile.swapAt(j, k)
        if pile[j] { found = true; break }
    }
    if found { hits += 1 }
}
let simulated = Double(hits) / Double(trials)

print("両面8枚待ち / 見えていない87枚 / 5回ツモ")
print("  式で計算       \(String(format: "%.2f", formula * 100))%")
print("  実際に引いた   \(String(format: "%.2f", simulated * 100))%  (\(trials)回)")
print("  1回あたり      8/87 = \(String(format: "%.2f", 8.0/87.0*100))%")
print("")
print("参考: 同じ待ちで回数を変えると")
for n in [1, 3, 5, 10] {
    var m = 1.0
    for i in 0..<n { m *= Double(unseen - waits - i) / Double(unseen - i) }
    print("  \(n)回ツモ: \(String(format: "%.0f", (1 - m) * 100))%")
}
