//
//  FlashCardController.swift
//  vocabulary
//

import UIKit
import AVFoundation

/// Reads words aloud with the system English voice.
private final class Pronouncer {
    static let shared = Pronouncer()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        // Play even when the ring/silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}

private final class FlashCardCell: UICollectionViewCell {
    private let cardView = UIView()
    private let stack = UIStackView()
    private let wordLabel = UILabel()
    private let ipaLabel = UILabel()
    private let speakButton = UIButton(type: .system)
    private let ipaRow = UIStackView()
    private let meanLabel = UILabel()
    private let exampleLabel = UILabel()

    /// Front shows only the word and IPA; the back shows everything.
    private var isFlipped = false
    private var hasMean = false
    private var hasExample = false
    private var spokenWord: String?

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

        speakButton.setImage(
            UIImage(systemName: "speaker.wave.2.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)),
            for: .normal
        )
        speakButton.tintColor = .systemTeal
        speakButton.accessibilityLabel = "Phát âm"
        speakButton.addTarget(self, action: #selector(speak), for: .touchUpInside)
        // Keep the tap target comfortably larger than the icon itself.
        speakButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            speakButton.widthAnchor.constraint(equalToConstant: 48),
            speakButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        ipaRow.axis = .horizontal
        ipaRow.spacing = 8
        ipaRow.alignment = .center
        [ipaLabel, speakButton].forEach { ipaRow.addArrangedSubview($0) }

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
        [wordLabel, ipaRow, meanLabel, exampleLabel].forEach { stack.addArrangedSubview($0) }

        contentView.addSubview(cardView)
        cardView.addSubview(stack)

        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(flip)))

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

    @objc private func speak() {
        guard let spokenWord else { return }
        Pronouncer.shared.speak(spokenWord)
    }

    @objc private func flip() {
        isFlipped.toggle()
        UIView.transition(
            with: cardView,
            duration: 0.45,
            options: [.transitionFlipFromRight, .allowUserInteraction]
        ) {
            self.updateBackFace()
        }
    }

    private func updateBackFace() {
        meanLabel.isHidden = !isFlipped || !hasMean
        exampleLabel.isHidden = !isFlipped || !hasExample
    }

    func configure(with item: JSONValue) {
        // A reused cell always starts on the front.
        isFlipped = false

        guard case .object(let pairs) = item, !pairs.isEmpty else {
            wordLabel.text = item.displayString
            ipaLabel.isHidden = true
            spokenWord = item.displayString.isEmpty ? nil : item.displayString
            speakButton.isHidden = spokenWord == nil
            ipaRow.isHidden = spokenWord == nil
            hasMean = false
            hasExample = false
            updateBackFace()
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
        spokenWord = word.isEmpty ? nil : word
        speakButton.isHidden = spokenWord == nil
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
        ipaRow.isHidden = ipaLabel.isHidden && speakButton.isHidden

        let mean = value(for: ["mean", "meaning"])
        meanLabel.text = mean
        hasMean = mean != nil

        let example = value(for: ["example"])
        exampleLabel.text = example
        hasExample = example != nil

        updateBackFace()
    }
}

class FlashCardController: UIViewController {

    var items: [JSONValue] = []
    var startIndex: Int = 0
    /// Section the words belong to; names the Realtime Database node ("remember_<title>").
    /// When nil, the "learned" switch is not shown.
    var sectionTitle: String?

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

    private let rememberSwitch = UISwitch()
    private var currentIndex = 0

    private let cellReuseIdentifier = "FlashCardCell"
    private var hasScrolledToStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Flashcard"
        view.backgroundColor = .systemBackground

        setupCollectionView()
        setupPageLabel()
        setupRememberSwitch()
        showPage(startIndex)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rememberedStoreChanged),
            name: RememberedStore.didChange,
            object: nil
        )
    }

    @objc private func rememberedStoreChanged() {
        syncRememberSwitch()
    }

    private func setupRememberSwitch() {
        guard sectionTitle != nil else { return }
        let label = UILabel()
        label.text = "Đã thuộc"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [label, rememberSwitch])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        // A custom bar-button view has no intrinsic size, so pin it to its fitted size or the switch gets clipped.
        let size = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: ceil(size.width)),
            stack.heightAnchor.constraint(equalToConstant: max(ceil(size.height), 32))
        ])
        let item = UIBarButtonItem(customView: stack)
        if #available(iOS 26.0, *) {
            // Drop the glass capsule iOS 26 draws behind bar items, which clips the switch.
            item.hidesSharedBackground = true
        }
        navigationItem.rightBarButtonItem = item

        rememberSwitch.addTarget(self, action: #selector(rememberToggled), for: .valueChanged)
    }

    private func showPage(_ index: Int) {
        currentIndex = index
        updatePageLabel(index: index)
        syncRememberSwitch()
    }

    private func syncRememberSwitch() {
        guard let sectionTitle, items.indices.contains(currentIndex) else { return }
        rememberSwitch.setOn(RememberedStore.shared.isRemembered(items[currentIndex], title: sectionTitle), animated: false)
    }

    @objc private func rememberToggled() {
        guard let sectionTitle, items.indices.contains(currentIndex) else { return }
        let remembered = rememberSwitch.isOn
        rememberSwitch.isEnabled = false

        RememberedStore.shared.setRemembered(remembered, item: items[currentIndex], title: sectionTitle) { [weak self] error in
            guard let self else { return }
            self.rememberSwitch.isEnabled = true
            self.syncRememberSwitch()
            if let error {
                let alert = UIAlertController(title: "Không lưu được", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
                self.present(alert, animated: true)
            }
        }
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
        showPage(max(0, min(index, items.count - 1)))
    }
}
