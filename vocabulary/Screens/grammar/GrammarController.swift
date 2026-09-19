//
//  GrammarController.swift
//  vocabulary
//

import UIKit
import WebKit

private final class TopicHeaderView: UIView {
    let titleLabel = UILabel()
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
    var onTap: (() -> Void)?

    var isExpanded: Bool = false {
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
        backgroundColor = .systemBackground

        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 13),
            chevronImageView.heightAnchor.constraint(equalToConstant: 13)
        ])

        updateChevron(animated: false)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func updateChevron(animated: Bool) {
        let transform = isExpanded ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
        if animated {
            UIView.animate(withDuration: 0.2) { self.chevronImageView.transform = transform }
        } else {
            chevronImageView.transform = transform
        }
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.backgroundColor = .systemGray5
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.backgroundColor = .systemBackground
            }
        })
        updateChevron(animated: true)
        onTap?()
    }
}

private final class GrammarContentCell: UITableViewCell {
    let webView: WKWebView = {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.scrollView.isScrollEnabled = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }()

    private let spinner = UIActivityIndicatorView(style: .medium)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        contentView.addSubview(webView)
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startLoading() {
        spinner.startAnimating()
    }

    func stopLoading() {
        spinner.stopAnimating()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }
}

class GrammarController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()

    private var topics: [GrammarTopic] = []
    private var expandedSections: Set<Int> = []
    private var measuredHeights: [Int: CGFloat] = [:]
    private var heightDelegates: [Int: WebViewHeightDelegate] = [:]

    private let contentCellID = "GrammarContentCell"
    private let defaultContentHeight: CGFloat = 240

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Grammar"
        view.backgroundColor = .systemBackground

        setupTableView()
        setupActivityIndicator()
        setupEmptyState()

        loadGrammar()
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(GrammarContentCell.self, forCellReuseIdentifier: contentCellID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.sectionHeaderTopPadding = 0
        tableView.separatorInset = .zero
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
        emptyStateLabel.text = "Chưa có nội dung ngữ pháp"
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.font = .systemFont(ofSize: 15)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.isHidden = true
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func loadGrammar() {
        activityIndicator.startAnimating()
        tableView.isHidden = true
        emptyStateLabel.isHidden = true

        RemoteConfigService.shared.fetchGrammar { [weak self] result in
            guard let self else { return }
            self.activityIndicator.stopAnimating()

            switch result {
            case .success(let topics):
                self.topics = topics
                self.expandedSections = []
                self.measuredHeights = [:]
                self.tableView.reloadData()
                self.tableView.isHidden = !topics.isEmpty ? false : true
                self.emptyStateLabel.isHidden = !topics.isEmpty ? true : false

            case .failure(let error):
                self.tableView.isHidden = true
                self.showError(error)
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
            self?.loadGrammar()
        })
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(alert, animated: true)
    }
}

extension GrammarController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        topics.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        expandedSections.contains(section) ? 1 : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: contentCellID, for: indexPath) as! GrammarContentCell
        let topic = topics[indexPath.section]
        let section = indexPath.section

        cell.startLoading()
        cell.webView.navigationDelegate = nil
        cell.webView.loadHTMLString(topic.html, baseURL: nil)

        let delegate = WebViewHeightDelegate { [weak self, weak tableView, weak cell] height in
            guard let self, let tableView else { return }
            cell?.stopLoading()
            let rounded = max(height, self.defaultContentHeight)
            if self.measuredHeights[section] != rounded {
                self.measuredHeights[section] = rounded
                UIView.performWithoutAnimation {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
            }
        }
        heightDelegates[section] = delegate
        cell.webView.navigationDelegate = delegate

        return cell
    }
}

extension GrammarController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = TopicHeaderView()
        header.titleLabel.text = topics[section].title
        header.isExpanded = expandedSections.contains(section)
        header.onTap = { [weak self] in
            self?.toggleSection(section)
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        50
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        measuredHeights[indexPath.section] ?? defaultContentHeight
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        measuredHeights[indexPath.section] ?? defaultContentHeight
    }
}

private final class WebViewHeightDelegate: NSObject, WKNavigationDelegate {
    private let onHeightMeasured: (CGFloat) -> Void

    init(onHeightMeasured: @escaping (CGFloat) -> Void) {
        self.onHeightMeasured = onHeightMeasured
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self, let number = result as? NSNumber else { return }
            self.onHeightMeasured(CGFloat(number.doubleValue))
        }
    }
}
