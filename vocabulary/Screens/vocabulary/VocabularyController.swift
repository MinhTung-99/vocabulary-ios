//
//  VocabularyController.swift
//  vocabulary
//

import UIKit

final class DayHeaderView: UIView {
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

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        // Set the flag without the non-animated didSet redraw, then rotate the chevron ourselves.
        isExpanded = expanded
        if animated {
            chevronImageView.transform = expanded ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
            updateChevron(animated: true)
        }
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
        onTap?()
    }
}

/// A day header drawn as an ordinary row (not a pinned section header), so it scrolls away with the content.
final class DayHeaderCell: UITableViewCell {
    static let reuseIdentifier = "DayHeaderCell"
    let dayHeader = DayHeaderView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .systemGray5
        // Taps are handled by the table's didSelectRow.
        dayHeader.isUserInteractionEnabled = false
        dayHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayHeader)
        NSLayoutConstraint.activate([
            dayHeader.topAnchor.constraint(equalTo: contentView.topAnchor),
            dayHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dayHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dayHeader.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dayHeader.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class EmptyStateView: UIView {
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

    private let searchController = UISearchController(searchResultsController: nil)

    private var sections: [VocabularySection] = []
    private var visibleSections: [VocabularySection] = []
    private var expandedSections: Set<String> = []
    private var searchQuery = ""
    private var isSearching: Bool { !searchQuery.isEmpty }

    private let cellReuseIdentifier = "VocabularyCell"

    /// Flat table rows: each day header followed by its words when expanded.
    private enum Row {
        case header(section: Int)
        case item(section: Int, index: Int)
    }
    private var rows: [Row] = []

    private func isExpanded(_ section: Int) -> Bool {
        isSearching || expandedSections.contains(visibleSections[section].key)
    }

    /// Lines show only between collapsed headers; none above the first row, below the last, or inside an expanded day.
    private func hidesSeparator(at row: Int) -> Bool {
        if row == rows.count - 1 { return true }
        switch rows[row] {
        case .item: return true
        case .header(let section): return isExpanded(section)
        }
    }

    private func updateSeparator(of cell: UITableViewCell, at row: Int) {
        cell.separatorInset = hidesSeparator(at: row)
            ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
            : .zero
    }

    private func rebuildRows() {
        rows = visibleSections.indices.flatMap { section -> [Row] in
            let items = isExpanded(section) ? visibleSections[section].items.indices.map { Row.item(section: section, index: $0) } : []
            return [.header(section: section)] + items
        }
    }
    /// Real row heights, keyed by section + word, so estimates match and rows don't jump while scrolling.
    private var rowHeightCache: [String: CGFloat] = [:]

    private func rowHeightKey(section: Int, index: Int) -> String {
        let vocabularySection = visibleSections[section]
        return vocabularySection.key + "|" + vocabularySection.items[index].wordText
    }

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

        if #available(iOS 26.0, *) {
            // Cut content off cleanly under the glass search bar, so a header sliding out doesn't peek through it.
            tableView.topEdgeEffect.style = .hard
        }

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.sectionHeaderTopPadding = 0
        // Zero-height header/footer remove the extra line above the first row and below the last.
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.register(DayHeaderCell.self, forCellReuseIdentifier: DayHeaderCell.reuseIdentifier)

        setupEmptyState()
        setupRefreshControl()
        setupSearch()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rememberedChanged),
            name: RememberedStore.didChange,
            object: nil
        )

        loadVocabularies(showsSpinner: true)
    }

    @objc private func rememberedChanged() {
        // Learned words must drop out of the already-scheduled reminders too.
        NotificationManager.shared.refreshFromSavedSettings(sections: sections)
        applyFilter()
    }

    @objc private func appWillEnterForeground() {
        NotificationManager.shared.refreshFromSavedSettings(sections: sections)
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

    private func setupSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Tìm từ vựng"
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func applyFilter() {
        // Words already marked as learned (stored in Realtime Database) are hidden.
        let unlearned: [VocabularySection] = sections.compactMap { section in
            let items = section.items.filter { !RememberedStore.shared.isRemembered($0, title: section.title) }
            if items.count == section.items.count { return section }
            return items.isEmpty ? nil : VocabularySection(key: section.key, items: items)
        }

        if isSearching {
            let matches: (String) -> Bool = {
                $0.range(of: self.searchQuery, options: .caseInsensitive) != nil
            }
            visibleSections = unlearned.compactMap { section in
                if matches(section.title) { return section }
                let items = section.items.filter { matches($0.searchableText) }
                return items.isEmpty ? nil : VocabularySection(key: section.key, items: items)
            }
        } else {
            visibleSections = unlearned
        }
        rebuildRows()
        tableView.reloadData()
        let isEmpty = visibleSections.isEmpty
        tableView.isHidden = isEmpty
        emptyStateView.isHidden = !isEmpty
        if isEmpty {
            let message: String
            if isSearching {
                message = "Không tìm thấy kết quả."
            } else if !sections.isEmpty {
                message = "Bạn đã thuộc hết các từ rồi."
            } else {
                message = "Danh sách từ vựng đang trống."
            }
            emptyStateView.configure(message: message)
        }
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
            guard case .success(let sections) = result else {
                self.activityIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                self.handleLoadFailure(result)
                return
            }

            // Fetch the learned words first so they never flash on screen; if that fails, show everything.
            RememberedStore.shared.refresh { [weak self] _ in
                guard let self else { return }
                self.activityIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                self.sections = sections
                NotificationManager.shared.refreshFromSavedSettings(sections: sections)
                self.applyFilter()
            }
        }
    }

    private func handleLoadFailure(_ result: Result<[VocabularySection], Error>) {
        guard case .failure(let error) = result else { return }
        if sections.isEmpty {
            tableView.isHidden = true
            emptyStateView.isHidden = false
            emptyStateView.configure(message: error.localizedDescription)
        } else {
            tableView.isHidden = false
            showError(error)
        }
    }

    private func toggleSection(_ section: Int) {
        guard !isSearching,
              let headerRow = rows.firstIndex(where: { if case .header(let s) = $0 { return s == section } else { return false } })
        else { return }
        let key = visibleSections[section].key
        let willExpand = !expandedSections.contains(key)
        if willExpand {
            expandedSections.insert(key)
        } else {
            expandedSections.remove(key)
        }
        rebuildRows()

        // Insert/delete just the word rows; the header row itself is never reloaded.
        let paths = visibleSections[section].items.indices.map { IndexPath(row: headerRow + 1 + $0, section: 0) }
        tableView.performBatchUpdates {
            if willExpand {
                tableView.insertRows(at: paths, with: .top)
            } else {
                tableView.deleteRows(at: paths, with: .top)
            }
        }
        (tableView.cellForRow(at: IndexPath(row: headerRow, section: 0)) as? DayHeaderCell)?
            .dayHeader.setExpanded(willExpand, animated: true)
        // Expanding/collapsing changes which rows are last or inside an open day.
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            if let cell = tableView.cellForRow(at: indexPath) { updateSeparator(of: cell, at: indexPath.row) }
        }
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
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .header(let section):
            let cell = tableView.dequeueReusableCell(withIdentifier: DayHeaderCell.reuseIdentifier, for: indexPath) as! DayHeaderCell
            let vocabularySection = visibleSections[section]
            cell.dayHeader.configure(
                title: vocabularySection.title,
                itemCount: vocabularySection.items.count,
                isExpanded: isExpanded(section)
            )
            return cell

        case .item(let section, let index):
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.attributedText = Self.attributedText(for: visibleSections[section].items[index])
            content.textProperties.numberOfLines = 0
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            cell.contentConfiguration = content
            return cell
        }
    }

    static func attributedText(for item: JSONValue) -> NSAttributedString {
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

        switch rows[indexPath.row] {
        case .header(let section):
            toggleSection(section)

        case .item(let section, let index):
            let flashCardController = UIStoryboard(name: "FlashCardController", bundle: nil)
                .instantiateInitialViewController() as! FlashCardController
            flashCardController.items = visibleSections[section].items
            flashCardController.sectionTitle = visibleSections[section].title
            flashCardController.startIndex = index
            navigationController?.pushViewController(flashCardController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        switch rows[indexPath.row] {
        case .header: return 44
        case .item(let section, let index): return rowHeightCache[rowHeightKey(section: section, index: index)] ?? 90
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard rows.indices.contains(indexPath.row) else { return }
        updateSeparator(of: cell, at: indexPath.row)
        guard case .item(let section, let index) = rows[indexPath.row] else { return }
        rowHeightCache[rowHeightKey(section: section, index: index)] = cell.frame.height
    }
}

extension VocabularyController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != searchQuery else { return }
        searchQuery = query
        applyFilter()
    }
}
