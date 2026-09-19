//
//  FlashCardController.swift
//  vocabulary
//

import UIKit

private final class FlashCardCell: UICollectionViewCell {
    private let cardView = UIView()
    private let stack = UIStackView()
    private let wordLabel = UILabel()
    private let ipaLabel = UILabel()
    private let meanLabel = UILabel()
    private let exampleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 24
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 16
        cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        wordLabel.font = .boldSystemFont(ofSize: 30)
        wordLabel.textColor = .label
        wordLabel.textAlignment = .center
        wordLabel.numberOfLines = 0

        ipaLabel.font = .systemFont(ofSize: 17)
        ipaLabel.textColor = .secondaryLabel
        ipaLabel.textAlignment = .center
        ipaLabel.numberOfLines = 0

        meanLabel.font = .systemFont(ofSize: 20, weight: .medium)
        meanLabel.textColor = .systemTeal
        meanLabel.textAlignment = .center
        meanLabel.numberOfLines = 0

        exampleLabel.font = .italicSystemFont(ofSize: 15)
        exampleLabel.textColor = .secondaryLabel
        exampleLabel.textAlignment = .center
        exampleLabel.numberOfLines = 0

        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        [wordLabel, ipaLabel, meanLabel, exampleLabel].forEach { stack.addArrangedSubview($0) }

        contentView.addSubview(cardView)
        cardView.addSubview(stack)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            stack.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
    }

    func configure(with item: JSONValue) {
        guard case .object(let pairs) = item, !pairs.isEmpty else {
            wordLabel.text = item.displayString
            ipaLabel.isHidden = true
            meanLabel.isHidden = true
            exampleLabel.isHidden = true
            return
        }

        func value(for keys: [String]) -> String? {
            for key in keys {
                if let match = pairs.first(where: { $0.key.lowercased() == key })?.value.displayString,
                   !match.isEmpty {
                    return match
                }
            }
            return nil
        }

        let word = value(for: ["word"]) ?? pairs[0].value.displayString
        if let partOfSpeech = value(for: ["part_of_speech"]) {
            let title = NSMutableAttributedString(
                string: word,
                attributes: [.font: UIFont.boldSystemFont(ofSize: 30), .foregroundColor: UIColor.label]
            )
            title.append(NSAttributedString(
                string: " - \(partOfSpeech)",
                attributes: [.font: UIFont.italicSystemFont(ofSize: 22), .foregroundColor: UIColor.systemOrange]
            ))
            wordLabel.attributedText = title
        } else {
            wordLabel.text = word
        }

        let ipa = value(for: ["ipa"])
        ipaLabel.text = ipa
        ipaLabel.isHidden = ipa == nil

        let mean = value(for: ["mean", "meaning"])
        meanLabel.text = mean
        meanLabel.isHidden = mean == nil

        let example = value(for: ["example"])
        exampleLabel.text = example
        exampleLabel.isHidden = example == nil
    }
}

class FlashCardController: UIViewController {

    var items: [JSONValue] = []
    var startIndex: Int = 0

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let pageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let cellReuseIdentifier = "FlashCardCell"
    private var hasScrolledToStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Flashcard"
        view.backgroundColor = .systemBackground

        setupCollectionView()
        setupPageLabel()
        updatePageLabel(index: startIndex)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !hasScrolledToStart, !items.isEmpty else { return }
        hasScrolledToStart = true
        let indexPath = IndexPath(item: startIndex, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
    }

    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FlashCardCell.self, forCellWithReuseIdentifier: cellReuseIdentifier)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36)
        ])
    }

    private func setupPageLabel() {
        view.addSubview(pageLabel)
        NSLayoutConstraint.activate([
            pageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func updatePageLabel(index: Int) {
        guard !items.isEmpty else {
            pageLabel.text = nil
            return
        }
        pageLabel.text = "\(index + 1) / \(items.count)"
    }
}

extension FlashCardController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as! FlashCardCell
        cell.configure(with: items[indexPath.item])
        return cell
    }
}

extension FlashCardController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard collectionView.bounds.width > 0 else { return }
        let index = Int((scrollView.contentOffset.x / collectionView.bounds.width).rounded())
        updatePageLabel(index: max(0, min(index, items.count - 1)))
    }
}
