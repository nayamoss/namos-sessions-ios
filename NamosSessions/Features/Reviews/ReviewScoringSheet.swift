import SwiftUI

struct ReviewScoringSheet: View {
    let row: ReviewerQueueRow
    let reviewerName: String
    let save: (Int?, String, [CriterionScore]) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var score: Int
    @State private var comments: String
    @State private var numberScores: [String: Int]
    @State private var textScores: [String: String]
    @State private var isSaving = false

    init(row: ReviewerQueueRow, reviewerName: String, save: @escaping (Int?, String, [CriterionScore]) async -> Bool) {
        self.row = row
        self.reviewerName = reviewerName
        self.save = save
        _score = State(initialValue: Int(row.review?.score ?? 1))
        _comments = State(initialValue: row.review?.comments ?? "")
        _numberScores = State(initialValue: Dictionary(uniqueKeysWithValues: (row.review?.criteriaScores ?? []).compactMap { item in item.value.map { (item.criterionId, Int($0)) } }))
        _textScores = State(initialValue: Dictionary(uniqueKeysWithValues: (row.review?.criteriaScores ?? []).compactMap { item in item.text.map { (item.criterionId, $0) } }))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(row.submissionTitle).font(.system(size: 18, weight: .semibold)).foregroundStyle(NamosColor.text)
                    if let abstract = row.submissionAnswers["abstract"], !abstract.isEmpty {
                        Text(abstract).font(.system(size: 14)).foregroundStyle(NamosColor.mutedText)
                    }
                }
                if let criteria = row.criteria, !criteria.isEmpty {
                    Section("Scorecard") {
                        ForEach(criteria) { criterion in
                            if criterion.type == "number" {
                                let max = Int(criterion.max ?? row.scoringScaleMax)
                                Stepper(value: numberBinding(for: criterion.id), in: 0...max) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(criterion.label)
                                        if criterion.required { Text("Required").font(.caption).foregroundStyle(NamosColor.mutedText) }
                                    }
                                }
                            } else {
                                TextField(criterion.label, text: textBinding(for: criterion.id), axis: .vertical)
                                    .lineLimit(2...5)
                            }
                        }
                    }
                } else {
                    Section("Overall score") {
                        Stepper("Score: \(score) of \(Int(row.scoringScaleMax))", value: $score, in: 1...Int(row.scoringScaleMax))
                    }
                }
                Section("Comments") { TextField("Optional comments", text: $comments, axis: .vertical).lineLimit(3...8) }
            }
            .navigationTitle("Score submission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await submit() } }.disabled(isSaving)
                }
            }
        }
    }

    private func numberBinding(for id: String) -> Binding<Int> { Binding(get: { numberScores[id] ?? 0 }, set: { numberScores[id] = $0 }) }
    private func textBinding(for id: String) -> Binding<String> { Binding(get: { textScores[id] ?? "" }, set: { textScores[id] = $0 }) }
    private func submit() async {
        isSaving = true
        let criteriaScores = (row.criteria ?? []).map { criterion in
            criterion.type == "number" ? CriterionScore(criterionId: criterion.id, value: Double(numberScores[criterion.id] ?? 0), text: nil) : CriterionScore(criterionId: criterion.id, value: nil, text: textScores[criterion.id])
        }
        if await save(row.criteria?.isEmpty == false ? nil : score, comments, criteriaScores) { dismiss() }
        isSaving = false
    }
}
