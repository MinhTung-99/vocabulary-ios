//
//  SettingsController.swift
//  vocabulary
//

import UIKit

private final class SwitchCell: UITableViewCell {
    private let label = UILabel()
    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none

        label.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        contentView.addSubview(label)
        contentView.addSubview(toggle)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        label.text = title
        toggle.isOn = isOn
        self.onChange = onChange
    }

    @objc private func toggleChanged() {
        onChange?(toggle.isOn)
    }
}

private final class StepperCell: UITableViewCell {
    private let label = UILabel()
    private let stepper = UIStepper()
    private var onChange: ((Double) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none

        label.translatesAutoresizingMaskIntoConstraints = false
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)

        contentView.addSubview(label)
        contentView.addSubview(stepper)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            stepper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, value: Double, range: ClosedRange<Double>, step: Double, onChange: @escaping (Double) -> Void) {
        label.text = title
        stepper.minimumValue = range.lowerBound
        stepper.maximumValue = range.upperBound
        stepper.stepValue = step
        stepper.value = value
        self.onChange = onChange
    }

    @objc private func stepperChanged() {
        onChange?(stepper.value)
    }
}

private final class DatePickerCell: UITableViewCell {
    private let label = UILabel()
    private let datePicker = UIDatePicker()
    private var onChange: ((Date) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none

        label.translatesAutoresizingMaskIntoConstraints = false

        datePicker.datePickerMode = .time
        datePicker.preferredDatePickerStyle = .compact
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        contentView.addSubview(label)
        contentView.addSubview(datePicker)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            datePicker.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            datePicker.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, date: Date, onChange: @escaping (Date) -> Void) {
        label.text = title
        datePicker.date = date
        self.onChange = onChange
    }

    @objc private func dateChanged() {
        onChange?(datePicker.date)
    }
}

final class SettingsController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case enabled, list, timeRange, interval
    }

    private typealias DefaultsKey = SettingsDefaultsKey

    private let sections: [VocabularySection]
    private var notificationsEnabled: Bool
    private var selectedSectionKeys: Set<String>
    private var intervalMinutes: Int
    private var startTime: Date
    private var endTime: Date

    private let listCellID = "listCell"
    private let stepperCellID = "stepperCell"
    private let switchCellID = "switchCell"
    private let dateCellID = "dateCell"

    init(sections: [VocabularySection]) {
        self.sections = sections

        let defaults = UserDefaults.standard
        self.notificationsEnabled = defaults.object(forKey: DefaultsKey.notificationsEnabled) as? Bool ?? false
        let savedKeys = Set(DefaultsKey.savedSectionKeys(defaults)).intersection(sections.map(\.key))
        self.selectedSectionKeys = savedKeys.isEmpty ? Set(sections.prefix(1).map(\.key)) : savedKeys

        let savedInterval = defaults.integer(forKey: DefaultsKey.intervalMinutes)
        self.intervalMinutes = savedInterval > 0 ? savedInterval : 60

        let calendar = Calendar.current
        func time(hourKey: String, minuteKey: String, defaultHour: Int, defaultMinute: Int) -> Date {
            let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour
            let minute = defaults.object(forKey: minuteKey) as? Int ?? defaultMinute
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }
        self.startTime = time(hourKey: DefaultsKey.startHour, minuteKey: DefaultsKey.startMinute, defaultHour: 8, defaultMinute: 0)
        self.endTime = time(hourKey: DefaultsKey.endHour, minuteKey: DefaultsKey.endMinute, defaultHour: 23, defaultMinute: 0)

        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cài đặt thông báo"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Lưu",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: listCellID)
        tableView.register(StepperCell.self, forCellReuseIdentifier: stepperCellID)
        tableView.register(SwitchCell.self, forCellReuseIdentifier: switchCellID)
        tableView.register(DatePickerCell.self, forCellReuseIdentifier: dateCellID)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        notificationsEnabled ? Section.allCases.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .enabled: return nil
        case .list: return "Danh sách từ vựng"
        case .timeRange: return "Khung giờ nhận thông báo"
        case .interval: return "Tần suất thông báo"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .enabled: return 1
        case .list: return sections.isEmpty ? 1 : sections.count
        case .timeRange: return 2
        case .interval: return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .enabled:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellID, for: indexPath) as! SwitchCell
            cell.configure(title: "Bật thông báo", isOn: notificationsEnabled) { [weak self] isOn in
                guard let self else { return }
                self.notificationsEnabled = isOn
                tableView.reloadData()
            }
            return cell

        case .list:
            let cell = tableView.dequeueReusableCell(withIdentifier: listCellID, for: indexPath)
            var content = cell.defaultContentConfiguration()
            if sections.isEmpty {
                content.text = "Chưa có danh sách từ vựng"
                cell.accessoryType = .none
                cell.selectionStyle = .none
            } else {
                let section = sections[indexPath.row]
                content.text = section.key
                content.secondaryText = "\(section.items.count) từ"
                cell.accessoryType = selectedSectionKeys.contains(section.key) ? .checkmark : .none
                cell.selectionStyle = .default
            }
            cell.contentConfiguration = content
            return cell

        case .timeRange:
            let cell = tableView.dequeueReusableCell(withIdentifier: dateCellID, for: indexPath) as! DatePickerCell
            if indexPath.row == 0 {
                cell.configure(title: "Từ", date: startTime) { [weak self] newDate in
                    self?.startTime = newDate
                }
            } else {
                cell.configure(title: "Đến", date: endTime) { [weak self] newDate in
                    self?.endTime = newDate
                }
            }
            return cell

        case .interval:
            let cell = tableView.dequeueReusableCell(withIdentifier: stepperCellID, for: indexPath) as! StepperCell
            cell.configure(
                title: "\(intervalMinutes) phút / lần",
                value: Double(intervalMinutes),
                range: 5...240,
                step: 5
            ) { [weak self] newValue in
                guard let self else { return }
                self.intervalMinutes = Int(newValue)
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .list, !sections.isEmpty else { return }
        let key = sections[indexPath.row].key
        if selectedSectionKeys.contains(key) {
            selectedSectionKeys.remove(key)
        } else {
            selectedSectionKeys.insert(key)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    @objc private func saveTapped() {
        let defaults = UserDefaults.standard
        defaults.set(notificationsEnabled, forKey: DefaultsKey.notificationsEnabled)

        guard notificationsEnabled else {
            NotificationManager.shared.cancelAllScheduled()
            showAlert(message: "Đã tắt thông báo.")
            return
        }

        // Keep the lists in their on-screen order.
        let selected = sections.filter { selectedSectionKeys.contains($0.key) }
        guard !selected.isEmpty else {
            showAlert(message: "Vui lòng chọn ít nhất một danh sách từ vựng.")
            return
        }
        let names = selected.map(\.key).joined(separator: ", ")

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        defaults.set(selected.map(\.key), forKey: DefaultsKey.selectedSectionKeys)
        defaults.set(intervalMinutes, forKey: DefaultsKey.intervalMinutes)
        defaults.set(startComponents.hour, forKey: DefaultsKey.startHour)
        defaults.set(startComponents.minute, forKey: DefaultsKey.startMinute)
        defaults.set(endComponents.hour, forKey: DefaultsKey.endHour)
        defaults.set(endComponents.minute, forKey: DefaultsKey.endMinute)

        guard !NotificationManager.shared.unlearnedEntries(in: selected).isEmpty else {
            NotificationManager.shared.cancelAllScheduled()
            showAlert(message: "Bạn đã thuộc hết các từ trong \(names), không còn từ nào để nhắc.")
            return
        }

        NotificationManager.shared.requestAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.showAlert(message: "Bạn cần cho phép thông báo trong Cài đặt hệ thống để dùng tính năng này.")
                return
            }
            let times = NotificationManager.shared.scheduleNotifications(
                sections: selected,
                intervalMinutes: self.intervalMinutes,
                startHour: startComponents.hour ?? 8,
                startMinute: startComponents.minute ?? 0,
                endHour: endComponents.hour ?? 23,
                endMinute: endComponents.minute ?? 0
            )
            let range = [times.first, times.last].compactMap { $0 }.joined(separator: " – ")
            self.showAlert(message: "Đã bật thông báo cho \(names): \(times.count) lần/ngày (\(range)), mỗi \(self.intervalMinutes) phút.")
        }
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
