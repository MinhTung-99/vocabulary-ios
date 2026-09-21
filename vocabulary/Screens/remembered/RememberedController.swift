//
//  RememberedController.swift
//  vocabulary
//

import UIKit

/// Lists the words marked as learned (from Firebase Realtime Database), laid out like the Vocabulary screen:
/// collapsible day sections, same cells, search and pull-to-refresh.
final class RememberedController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let emptyStateView = EmptyStateView()
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)

    private var groups: [RememberedGroup] = []
    private var visibleGroups: [RememberedGroup] = []
    private var expandedTitles: Set<String> = []
    private var searchQuery = ""
    private var isSearching: Bool { !searchQuery.isEmpty }
    private var lastError: Error?

    private let cellReuseIdentifier = "RememberedCell"

    /// Flat table rows: each day header followed by its words when expanded.
    private enum Row {
        case header(section: Int)
        case item(section: Int, index: Int)
    }
    private var rows: [Row] = []
    /// Real row heights, keyed by group + word, so estimates match and rows don't jump while scrolling.
    private var rowHeightCache: [String: CGFloat] = [:]

    private func isExpanded(_ section: Int) -> Bool {
        isSearching || expandedTitles.contains(visibleGroups[section].title)
    }

    private func rowHeightKey(section: Int, index: Int) -> String {
        let group = visibleGroups[section]
        return group.title + "|" + group.items[index].wordText
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
        rows = visibleGroups.indices.flatMap { section -> [Row] in
            let items = isExpanded(section) ? visibleGroups[section].items.indices.map { Row.item(section: section, index: $0) } : []
            return [.header(section: section)] + items
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Remembered"
        view.backgroundColor = .systemBackground

        setupTableView()
        setupActivityIndicator()
        setupEmptyState()
        setupSearch()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: RememberedStore.didChange,
            object: nil
        )

        load(showsSpinner: true)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.register(DayHeaderCell.self, forCellReuseIdentifier: DayHeaderCell.reuseIdentifier)
        if #available(iOS 26.0, *) {
            // Cut content off cleanly under the glass search bar.
            tableView.topEdgeEffect.style = .hard
        }
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.sectionHeaderTopPadding = 0
        // Zero-height header/footer remove the extra line above the first row and below the last.
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.onRetry = { [weak self] in
            self?.load(showsSpinner: true)
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
        searchController.searchBar.placeholder = "Tìm từ đã thuộc"
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    @objc private func refreshPulled() {
        load(showsSpinner: false)
    }

    @objc private func storeChanged() {
        applyFilter()
    }

    private func load(showsSpinner: Bool) {
        if showsSpinner {
            activityIndicator.startAnimating()
            tableView.isHidden = true
            emptyStateView.isHidden = true
        }

        RememberedStore.shared.refresh { [weak self] error in
            guard let self else { return }
            self.activityIndicator.stopAnimating()
            self.refreshControl.endRefreshing()
            self.lastError = error
            self.applyFilter()
        }
    }

    private func applyFilter() {
        groups = RememberedStore.shared.groups

        if isSearching {
            let matches: (String) -> Bool = {
                $0.range(of: self.searchQuery, options: .caseInsensitive) != nil
            }
            visibleGroups = groups.compactMap { group in
                if matches(group.title) { return group }
                let items = group.items.filter { matches($0.searchableText) }
                return items.isEmpty ? nil : RememberedGroup(title: group.title, items: items)
            }
        } else {
            visibleGroups = groups
        }
        rebuildRows()
        tableView.reloadData()

        let isEmpty = visibleGroups.isEmpty
        tableView.isHidden = isEmpty
        emptyStateView.isHidden = !isEmpty
        if isEmpty {
            if isSearching {
                emptyStateView.configure(message: "Không tìm thấy kết quả.")
            } else if let lastError, groups.isEmpty {
                emptyStateView.configure(message: lastError.localizedDescription)
            } else {
                emptyStateView.configure(message: "Chưa có từ nào đã thuộc.")
            }
        }
    }

    private func toggleSection(_ section: Int) {
        guard !isSearching,
              let headerRow = rows.firstIndex(where: { if case .header(let s) = $0 { return s == section } else { return false } })
        else { return }
        let title = visibleGroups[section].title
        let willExpand = !expandedTitles.contains(title)
        if willExpand {
            expandedTitles.insert(title)
        } else {
            expandedTitles.remove(title)
        }
        rebuildRows()

        // Insert/delete just the word rows; the header row itself is never reloaded.
        let paths = visibleGroups[section].items.indices.map { IndexPath(row: headerRow + 1 + $0, section: 0) }
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
}

extension RememberedController: UITableViewDataSource {
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
            let group = visibleGroups[section]
            cell.dayHeader.configure(title: group.title, itemCount: group.items.count, isExpanded: isExpanded(section))
            return cell

        case .item(let section, let index):
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.attributedText = VocabularyController.attributedText(for: visibleGroups[section].items[index])
            content.textProperties.numberOfLines = 0
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            cell.contentConfiguration = content
            return cell
        }
    }
}

extension RememberedController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch rows[indexPath.row] {
        case .header(let section):
            toggleSection(section)

        case .item(let section, let index):
            let flashCardController = UIStoryboard(name: "FlashCardController", bundle: nil)
                .instantiateInitialViewController() as! FlashCardController
            flashCardController.items = visibleGroups[section].items
            flashCardController.sectionTitle = visibleGroups[section].title
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

extension RememberedController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != searchQuery else { return }
        searchQuery = query
        applyFilter()
    }
}
