//
//  VocabularyController.swift
//  vocabulary
//

import UIKit

private final class DayHeaderView: UIView {
    let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
    var onTap: (() -> Void)?

    var isExpanded: Bool = true {
        didSet { updateChevron(animated: false) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemGray5

        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = .systemFont(ofSize: 13)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .firstBaseline
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 13),
            chevronImageView.heightAnchor.constraint(equalToConstant: 13)
        ])

        updateChevron(animated: false)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    func configure(title: String, itemCount: Int, isExpanded: Bool) {
        titleLabel.text = title
        countLabel.text = "\(itemCount) từ"
        self.isExpanded = isExpanded
    }

    private func updateChevron(animated: Bool) {
        let transform = isExpanded
            ? CGAffineTransform(rotationAngle: .pi / 2)
            : .identity
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.chevronImageView.transform = transform
            }
        } else {
            chevronImageView.transform = transform
        }
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.backgroundColor = .systemGray4
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.backgroundColor = .systemGray5
            }
        })
        updateChevron(animated: true)
        onTap?()
    }
}

private final class EmptyStateView: UIView {
    var onRetry: (() -> Void)?

    private let iconView = UIImageView(image: UIImage(systemName: "text.book.closed"))
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        iconView.tintColor = .tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.text = "Chưa có dữ liệu"

        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        retryButton.setTitle("Thử lại", for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, retryButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(16, after: messageLabel)

        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    func configure(message: String) {
        messageLabel.text = message
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}

class VocabularyController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private let emptyStateView = EmptyStateView()
    private let refreshControl = UIRefreshControl()

    private var sections: [VocabularySection] = []
    private var expandedSections: Set<Int> = []

    private let cellReuseIdentifier = "VocabularyCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Vocabulary"
        activityIndicator.hidesWhenStopped = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.sectionHeaderTopPadding = 0

        setupEmptyState()
        setupRefreshControl()

        loadVocabularies(showsSpinner: true)
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.onRetry = { [weak self] in
            self?.loadVocabularies(showsSpinner: true)
        }
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshPulled() {
        loadVocabularies(showsSpinner: false)
    }

    @objc private func settingsTapped() {
        let settingsController = SettingsController(sections: sections)
        navigationController?.pushViewController(settingsController, animated: true)
    }

    private func loadVocabularies(showsSpinner: Bool) {
        if showsSpinner {
            activityIndicator.startAnimating()
            tableView.isHidden = true
            emptyStateView.isHidden = true
        }

        RemoteConfigService.shared.fetchVocabularies { [weak self] result in
            guard let self else { return }
            self.activityIndicator.stopAnimating()
            self.refreshControl.endRefreshing()

            switch result {
            case .success(let sections):
                self.sections = sections
                self.expandedSections = Set(sections.indices)
                self.tableView.reloadData()

                let isEmpty = sections.isEmpty
                self.tableView.isHidden = isEmpty
                self.emptyStateView.isHidden = !isEmpty
                if isEmpty {
                    self.emptyStateView.configure(message: "Danh sách từ vựng đang trống.")
                }

            case .failure(let error):
                if self.sections.isEmpty {
                    self.tableView.isHidden = true
                    self.emptyStateView.isHidden = false
                    self.emptyStateView.configure(message: error.localizedDescription)
                } else {
                    self.tableView.isHidden = false
                    self.showError(error)
                }
            }
        }
    }

    private func toggleSection(_ section: Int) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
        tableView.reloadSections(IndexSet(integer: section), with: .automatic)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Không tải được dữ liệu",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Thử lại", style: .default) { [weak self] _ in
            self?.loadVocabularies(showsSpinner: true)
        })
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(alert, animated: true)
    }
}

extension VocabularyController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        expandedSections.contains(section) ? sections[section].items.count : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.attributedText = Self.attributedText(for: item)
        content.textProperties.numberOfLines = 0
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        cell.contentConfiguration = content

        return cell
    }

    private static func attributedText(for item: JSONValue) -> NSAttributedString {
        guard case .object(let pairs) = item, !pairs.isEmpty else {
            return NSAttributedString(
                string: item.displayString,
                attributes: [.font: UIFont.systemFont(ofSize: 15)]
            )
        }

        let lineSpacing = NSMutableParagraphStyle()
        lineSpacing.paragraphSpacing = 4

        let result = NSMutableAttributedString()

        // Title: "word - part_of_speech" (falls back to the first field if there's no "word").
        let wordPair = pairs.first { $0.key.lowercased() == "word" } ?? pairs[0]
        let partOfSpeech = pairs.first { $0.key.lowercased() == "part_of_speech" }?.value.displayString

        result.append(NSAttributedString(
            string: wordPair.value.displayString,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.label,
                .paragraphStyle: lineSpacing
            ]
        ))
        if let partOfSpeech, !partOfSpeech.isEmpty {
            result.append(NSAttributedString(
                string: " - \(partOfSpeech)",
                attributes: [
                    .font: UIFont.italicSystemFont(ofSize: 15),
                    .foregroundColor: UIColor.systemOrange,
                    .paragraphStyle: lineSpacing
                ]
            ))
        }

        let remaining = pairs.filter {
            $0.key.lowercased() != wordPair.key.lowercased() && $0.key.lowercased() != "part_of_speech"
        }

        for pair in remaining {
            result.append(NSAttributedString(string: "\n"))
            result.append(NSAttributedString(
                string: "\(pair.key.uppercased())  ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: lineSpacing
                ]
            ))

            let (valueFont, valueColor): (UIFont, UIColor) = {
                switch pair.key.lowercased() {
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

            result.append(NSAttributedString(
                string: pair.value.displayString,
                attributes: [
                    .font: valueFont,
                    .foregroundColor: valueColor,
                    .paragraphStyle: lineSpacing
                ]
            ))
        }
        return result
    }
}

extension VocabularyController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let flashCardController = UIStoryboard(name: "FlashCardController", bundle: nil)
            .instantiateInitialViewController() as! FlashCardController
        flashCardController.items = sections[indexPath.section].items
        flashCardController.startIndex = indexPath.row
        navigationController?.pushViewController(flashCardController, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = DayHeaderView()
        let vocabularySection = sections[section]
        header.configure(
            title: vocabularySection.title,
            itemCount: vocabularySection.items.count,
            isExpanded: expandedSections.contains(section)
        )
        header.onTap = { [weak self] in
            self?.toggleSection(section)
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}
