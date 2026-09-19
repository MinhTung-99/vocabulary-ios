//
//  NotificationViewController.swift
//  NotificationContent
//
//  Renders the full title/body of a vocabulary reminder notification,
//  since the default banner/notification-center preview truncates long text.
//  When the payload includes structured "fields" (see NotificationManager),
//  each field (ipa, mean, example, part_of_speech, ...) is rendered in its
//  own color, matching the styling used in the main app's list/flashcard UI.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    private func setupViews() {
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.font = .systemFont(ofSize: 15)
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        guard let fields = Self.extractFields(from: content.userInfo["fields"]), !fields.isEmpty else {
            titleLabel.text = content.title
            bodyLabel.text = content.body
            return
        }
        render(fields: fields)
    }

    /// Local-notification `userInfo` can come back as `NSArray`/`NSString` (rather than
    /// bridging cleanly to `[[String]]`) once a scheduled notification round-trips through
    /// the system, so this unpacks it defensively instead of relying on a single `as?` cast.
    private static func extractFields(from raw: Any?) -> [[String]]? {
        guard let array = raw as? [Any] else { return nil }
        let pairs = array.compactMap { element -> [String]? in
            guard let pairArray = element as? [Any] else { return nil }
            let strings = pairArray.compactMap { $0 as? String }
            return strings.isEmpty ? nil : strings
        }
        return pairs.isEmpty ? nil : pairs
    }

    private func render(fields: [[String]]) {
        func value(forKey key: String) -> String? {
            fields.first { $0.first?.lowercased() == key }?.last
        }

        let title = NSMutableAttributedString()
        let word = value(forKey: "word") ?? fields.first?.last ?? ""
        title.append(NSAttributedString(
            string: word,
            attributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.label]
        ))
        if let partOfSpeech = value(forKey: "part_of_speech"), !partOfSpeech.isEmpty {
            title.append(NSAttributedString(
                string: " - \(partOfSpeech)",
                attributes: [.font: UIFont.italicSystemFont(ofSize: 15), .foregroundColor: UIColor.systemOrange]
            ))
        }
        titleLabel.attributedText = title

        let excludedKeys: Set<String> = ["word", "part_of_speech"]
        let remaining = fields.filter { pair in
            guard let key = pair.first?.lowercased() else { return false }
            return !excludedKeys.contains(key)
        }

        let body = NSMutableAttributedString()
        for (index, pair) in remaining.enumerated() {
            guard pair.count == 2 else { continue }
            let key = pair[0]
            let value = pair[1]

            if index > 0 {
                body.append(NSAttributedString(string: "\n"))
            }
            body.append(NSAttributedString(
                string: "\(key.uppercased())  ",
                attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: UIColor.secondaryLabel]
            ))

            let (font, color): (UIFont, UIColor) = {
                switch key.lowercased() {
                case "ipa":
                    return (.systemFont(ofSize: 15), .systemIndigo)
                case "mean", "meaning":
                    return (.systemFont(ofSize: 15, weight: .medium), .systemTeal)
                case "example":
                    return (.italicSystemFont(ofSize: 15), .secondaryLabel)
                default:
                    return (.systemFont(ofSize: 15), .label)
                }
            }()
            body.append(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color]))
        }
        bodyLabel.attributedText = body
    }
}
