#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DiaryDevelopmentSeed {
    static func installIfRequested(in container: ModelContainer, arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        let environment = ProcessInfo.processInfo.environment
        guard arguments.contains("-pettaleDiarySeed") || environment["PETTALE_DIARY_SEED"] == "1" else { return }
        let context = container.mainContext
        guard try context.fetchCount(FetchDescriptor<Pet>()) == 0 else { return }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let morning = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now) ?? now
        let evening = calendar.date(bySettingHour: 19, minute: 40, second: 0, of: now) ?? now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: morning) ?? morning

        let oreo = try Pet(name: "Oreo", species: .cat)
        let creamy = try Pet(name: "Creamy", species: .cat)
        let milo = try Pet(name: "Milo", species: .dog)
        let coco = try Pet(name: "Coco", species: .dog)
        context.insert(oreo)
        context.insert(creamy)
        context.insert(milo)
        context.insert(coco)

        let morningRecord = try PetRecord(
            pet: oreo,
            originalTranscript: "오레오는 오늘 아침과 점심, 저녁에 밥을 먹고 잘 놀았어. 체중은 6.2kg이야.",
            diaryText: "오늘 오레오는 아침 6시, 낮 12시, 저녁 6시에 밥을 먹었어요. 하루 종일 잘 놀았고 체중은 6.2kg이에요.",
            recordedAt: morning
        )
        context.insert(morningRecord)
        for hour in [6, 12, 18] {
            let time = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)
            context.insert(try PetEvent(record: morningRecord, category: .food, occurredAt: time))
        }
        context.insert(try PetEvent(record: morningRecord, category: .activity, eventType: "PLAY"))
        context.insert(try PetEvent(record: morningRecord, category: .weight, eventType: "BODY_WEIGHT", numericValue: 6.2, unit: "KG"))

        for (daysAgo, weight) in [(94, 6.4), (63, 6.3), (33, 6.25), (16, 6.2)] {
            let measuredAt = calendar.date(byAdding: .day, value: -daysAgo, to: morning) ?? morning
            let record = try PetRecord(pet: oreo, originalTranscript: "Development weight history", recordedAt: measuredAt)
            context.insert(record)
            context.insert(try PetEvent(record: record, category: .weight, eventType: "BODY_WEIGHT", numericValue: weight, unit: "KG"))
        }

        let eveningRecord = try PetRecord(
            pet: oreo,
            originalTranscript: "오레오가 저녁 산책 뒤 편안하게 쉬었어.",
            diaryText: "저녁 산책을 마친 오레오는 편안하게 쉬었어요.",
            recordedAt: evening
        )
        context.insert(eveningRecord)
        context.insert(try PetEvent(record: eveningRecord, category: .activity, eventType: "PLAY", durationMinutes: 20))

        let historical = try PetRecord(
            pet: oreo,
            originalTranscript: "어제 오레오가 밥을 잘 먹었어.",
            recordedAt: yesterday
        )
        context.insert(historical)
        context.insert(try PetEvent(record: historical, category: .food))

        let creamyRecord = try PetRecord(
            pet: creamy,
            originalTranscript: "오늘 크리미 왼쪽 눈이 조금 빨갛고 눈물이 났어.",
            diaryText: "오늘 크리미의 왼쪽 눈이 조금 빨갛고 눈물이 났어요.",
            recordedAt: morning
        )
        context.insert(creamyRecord)
        context.insert(try PetEvent(
            record: creamyRecord,
            category: .health,
            eventType: "EYE_REDNESS",
            description: "Left eye looked a little red and watery"
        ))
        for (daysAgo, weight) in [(77, 5.1), (47, 5.2), (0, 5.2)] {
            let measuredAt = calendar.date(byAdding: .day, value: -daysAgo, to: morning) ?? morning
            let record = try PetRecord(pet: creamy, originalTranscript: "Development weight history", recordedAt: measuredAt)
            context.insert(record)
            context.insert(try PetEvent(record: record, category: .weight, eventType: "BODY_WEIGHT", numericValue: weight, unit: "KG"))
        }

        let miloRecord = try PetRecord(pet: milo, originalTranscript: "Development single weight", recordedAt: morning)
        context.insert(miloRecord)
        context.insert(try PetEvent(record: miloRecord, category: .weight, eventType: "BODY_WEIGHT", numericValue: 8.4, unit: "KG"))
        try context.save()
    }
}
#endif
