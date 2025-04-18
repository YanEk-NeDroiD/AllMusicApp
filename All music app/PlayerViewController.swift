import UIKit
import AVFoundation

class PlayerViewController: UIViewController {

    public var position: Int = 0
    public var songs: [Song] = []
    
    @IBOutlet weak var holder: UIView!

    private var player: AVAudioPlayer?
    private var radioPlayer: AVPlayer?
    private var timer: Timer?

    private let albumImageView = UIImageView()
    private let songNameLabel = UILabel()
    private let artistNameLabel = UILabel()
    private let albumNameLabel = UILabel()

    private var playPauseButton: UIButton!
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let slider = UISlider()
    private let volumeSlider = UISlider()
    private let backgroundView = UIView()

    private var isRadioMode: Bool = false

    // ✅ 10 радиостанций
    private let radioStations: [String] = [
        "Relax FM",
        "Nashe Radio",
        "Mayak FM",
        "Vesti FM",
        "Jazz Radio",
        "Oldie Radio",
        "Radio Art Jazz",
        "Sky Plus",
        "Radio 1",
        "Radio Paradise"
    ]

    private let radioURLs: [URL] = [
        URL(string: "https://stream.relax-fm.ru/relaxfm")!,
        URL(string: "https://nashe1.hostingradio.ru:80/nashe-256")!,
        URL(string: "https://icecast-vgtrk.cdnvideo.ru/mayakfm_mp3_192kbps")!,
        URL(string: "https://icecast-vgtrk.cdnvideo.ru/vesti-fm_mp3_192kbps")!,
        URL(string: "https://streaming.radionomy.com/JazzRadio")!,
        URL(string: "https://stream.laut.fm/oldieradio")!,
        URL(string: "https://live.radioart.com/fJazz.mp3")!,
        URL(string: "https://radio.skyplus.ee/skyplus.mp3")!,
        URL(string: "https://icecast.omroep.nl/radio1-bb-mp3")!,
        URL(string: "https://stream.radioparadise.com/mp3-192")!
    ]

    private var currentRadioIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        configureUI()
        setupPlayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        albumImageView.frame = CGRect(x: 20, y: 40, width: holder.frame.width - 40, height: holder.frame.width - 40)
        songNameLabel.frame = CGRect(x: 10, y: albumImageView.frame.maxY + 10, width: holder.frame.width - 20, height: 50)
        albumNameLabel.frame = CGRect(x: 10, y: songNameLabel.frame.maxY + 5, width: holder.frame.width - 20, height: 30)
        artistNameLabel.frame = CGRect(x: 10, y: albumNameLabel.frame.maxY + 5, width: holder.frame.width - 20, height: 30)

        let buttonStack = holder.subviews.first(where: { $0 is UIStackView }) as? UIStackView
        buttonStack?.frame = CGRect(x: 20, y: artistNameLabel.frame.maxY + 30, width: holder.frame.width - 40, height: 50)

        // Надпись под кнопкой радио
        if let radioLabel = holder.viewWithTag(999) {
            radioLabel.frame = CGRect(x: 0, y: (buttonStack?.frame.maxY ?? 0) + 5, width: holder.frame.width, height: 20)
        }

        volumeSlider.frame = CGRect(x: 20, y: holder.frame.height - 60, width: holder.frame.width - 40, height: 30)

        slider.isHidden = true
        currentTimeLabel.isHidden = true
        durationLabel.isHidden = true
    }

    private func setupBackground() {
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.insertSubview(backgroundView, at: 0)
    }

    private func configureUI() {
        albumImageView.contentMode = .scaleAspectFill
        albumImageView.clipsToBounds = true
        albumImageView.layer.cornerRadius = 12

        [songNameLabel, artistNameLabel, albumNameLabel].forEach {
            $0.textColor = .white
            $0.textAlignment = .center
            $0.numberOfLines = 1
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.5
            $0.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        }

        [albumImageView, songNameLabel, artistNameLabel, albumNameLabel, slider, currentTimeLabel, durationLabel, volumeSlider].forEach {
            holder.addSubview($0)
        }

        slider.addTarget(self, action: #selector(didSlideSlider(_:)), for: .valueChanged)
        volumeSlider.addTarget(self, action: #selector(didSlideVolume(_:)), for: .valueChanged)
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 0.5

        setupButtons()
    }

    private func setupPlayer() {
        timer?.invalidate()
        player?.stop()
        radioPlayer?.pause()
        isRadioMode = false

        guard let song = songs[safe: position],
              let path = Bundle.main.path(forResource: song.trackName, ofType: "mp3") else {
            print("Ошибка: трек не найден")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            player?.delegate = self
            player?.prepareToPlay()
            player?.volume = volumeSlider.value
            player?.play()

            albumImageView.image = UIImage(named: song.imageName)
            songNameLabel.text = song.name
            albumNameLabel.text = song.albumName
            artistNameLabel.text = song.artistName

            slider.maximumValue = Float(player?.duration ?? 1.0)
            slider.value = 0.0

            updateTimeLabels()
            startTimer()

            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        } catch {
            print("Ошибка воспроизведения: \(error)")
        }
    }

    private func playRadioStream(url: URL) {
        timer?.invalidate()
        player?.stop()
        isRadioMode = true

        radioPlayer = AVPlayer(url: url)
        radioPlayer?.volume = volumeSlider.value
        radioPlayer?.play()

        songNameLabel.text = radioStations[currentRadioIndex]
        artistNameLabel.text = "Streaming Live"
        albumNameLabel.text = ""
        albumImageView.image = UIImage(systemName: "dot.radiowaves.left.and.right")

        slider.value = 0
        slider.isEnabled = false
        currentTimeLabel.text = "--:--"
        durationLabel.text = "--:--"

        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
    }

    private func setupButtons() {
        playPauseButton = createStyledButton(systemName: "pause.fill", action: #selector(didTapPlayPauseButton))
        let nextButton = createStyledButton(systemName: "forward.fill", action: #selector(didTapNextButton))
        let backButton = createStyledButton(systemName: "backward.fill", action: #selector(didTapBackButton))

        let radioButton = createStyledButton(systemName: "dot.radiowaves.left.and.right", action: #selector(didTapRadioButton))
        radioButton.tintColor = .systemRed // ✅ выделен цветом

        let buttonStack = UIStackView(arrangedSubviews: [backButton, playPauseButton, nextButton, radioButton])
        buttonStack.axis = .horizontal
        buttonStack.distribution = .equalSpacing
        buttonStack.spacing = 15
        holder.addSubview(buttonStack)

        // ✅ подпись "Радио" под кнопкой радио
        let radioLabel = UILabel()
        radioLabel.text = "Радио"
        radioLabel.textAlignment = .center
        radioLabel.textColor = .white
        radioLabel.font = UIFont.systemFont(ofSize: 14)
        radioLabel.tag = 999
        holder.addSubview(radioLabel)
        
        // Убираем потенциальную ошибку с ограничениями
        radioButton.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            buttonStack.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: holder.centerYAnchor, constant: 60)
        ])
    }

    private func createStyledButton(systemName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func didTapBackButton() {
        position = (position - 1 + songs.count) % songs.count
        setupPlayer()
    }

    @objc private func didTapNextButton() {
        position = (position + 1) % songs.count
        setupPlayer()
    }

    @objc private func didTapRadioButton() {
        // Переключаем радиостанцию
        currentRadioIndex = (currentRadioIndex + 1) % radioStations.count
        playRadioStream(url: radioURLs[currentRadioIndex])
    }

    @objc private func didTapPlayPauseButton() {
        if isRadioMode {
            if radioPlayer?.timeControlStatus == .playing {
                radioPlayer?.pause()
                playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            } else {
                radioPlayer?.play()
                playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            }
        } else {
            guard let player = player else { return }
            if player.isPlaying {
                player.pause()
                playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            } else {
                player.play()
                playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            }
        }
    }

    @objc private func didSlideSlider(_ sender: UISlider) {
        guard !isRadioMode else { return }
        player?.currentTime = TimeInterval(sender.value)
        updateTimeLabels()
    }

    @objc private func didSlideVolume(_ sender: UISlider) {
        player?.volume = sender.value
        radioPlayer?.volume = sender.value
    }

    private func updateTimeLabels() {
        guard let player = player, !isRadioMode else { return }
        let current = Int(player.currentTime)
        let duration = Int(player.duration)

        currentTimeLabel.text = String(format: "%d:%02d", current / 60, current % 60)
        durationLabel.text = String(format: "%d:%02d", duration / 60, duration % 60)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let player = self.player else { return }
            self.slider.value = Float(player.currentTime)
            self.updateTimeLabels()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.stop()
        radioPlayer?.pause()
        timer?.invalidate()
    }
}

extension PlayerViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        position = (position + 1) % songs.count
        setupPlayer()
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

