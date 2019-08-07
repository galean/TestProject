//
//  VideoRecorderViewController.swift
//  VideoSolution
//
//  Created Galean Pallerman on 26.07.2019.
//  Copyright © 2019 GPco. All rights reserved.
//
//  Template generated by Galean Pallerman
//

import UIKit
import Foundation

class VideoRecorderVC: UIViewController {
    private var presenter : VideoRecorderViewToPresenterProtocol!
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var videoPreviewImageView: UIImageView!
    @IBOutlet weak var torchButton: UIButton!
    @IBOutlet weak var videoSwitchButton: UIButton!
    @IBOutlet weak var audioMuteButton: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var galleryButton: UIButton!
    @IBOutlet weak var libraryLastImageView: UIImageView!
        
    @IBOutlet weak var timeLabel: UILabel!
    var counter = 0
    var timer = Timer()

    //MARK: Initialization
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.configureConnections()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func configureConnections() {
        let interactor = VideoRecorderInteractor()
        let presenter = VideoRecorderPresenter()
        
        self.configure(presenter: presenter)
        presenter.configure(interactor: interactor, viewController: self)
        interactor.configure(presenter: presenter)
    }
    
    func configure(presenter: VideoRecorderViewToPresenterProtocol) {
        self.presenter = presenter
    }
    
    //MARK: Internal
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.viewDidLoad()
    }
    
    func configureView() {
        styleCaptureButton()
    }
    
    func styleCaptureButton() {
        captureButton.layer.borderColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        captureButton.layer.borderWidth = 3

        captureButton.layer.cornerRadius = min(captureButton.frame.width, captureButton.frame.height) / 2
    }
    
    func internalStartRecording(){
        let selected = !captureButton.isSelected
        captureButton.isSelected = selected
        selected ? presenter.startRecordingButtonClicked() : presenter.stopRecordingButtonClicked()
    }
    
    func internalStartTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
        timeLabel.alpha = 1
    }
    
    func internalResetTimer() {
        timer.invalidate()
        counter = 0
        timeLabel.text = "00:00:00"
        timeLabel.alpha = 0
    }
    
    @objc func updateTimer() {
        counter = counter + 1
        let hours = Int(counter) / 3600
        let minutes = Int(counter) / 60 % 60
        let seconds = Int(counter) % 60
        timeLabel.text = String(format:"%02i:%02i:%02i", hours, minutes, seconds)
    }
}

//MARK:- IBActions
extension VideoRecorderVC {
    @IBAction func captureButtonClicked(_ sender: Any) {
        internalStartRecording()
    }
    
    @IBAction func galleryButtonClicked(_ sender: Any) {
        presenter.galleryButtonClicked()
    }
    
    @IBAction func switchButtonClicked(_ sender: Any) {
        presenter.switchCameraButtonClicked()
    }
    
    @IBAction func torchButtonClicked(_ sender: Any) {
        presenter.torchButtonClicked()
    }
    
    @IBAction func muteButtonClicked(_ sender: Any) {
        presenter.muteButtonClicked()
    }
}

//MARK:- VideoRecorderPresenterToViewProtocol
extension VideoRecorderVC: VideoRecorderPresenterToViewProtocol {
    func display(videoPreview: UIImage) {
        videoPreviewImageView.image = videoPreview
    }
    
    func flipVideoPreview(){
        self.videoPreviewImageView.image = nil
        UIView.transition(with: self.videoPreviewView, duration: 0.25, options: .transitionFlipFromLeft, animations: {
        }, completion: nil)
    }
    
    func changeAudioButton(muted: Bool) {
        let title = muted ? "Unmute" : "Mute"
        audioMuteButton.setTitle(title, for: .normal)
    }
    
    func changeTorchButton(mode: TorchMode) {
        var image = #imageLiteral(resourceName: "btn-icon-mainview-torch-auto")
        
        switch mode {
        case .off:
            image = #imageLiteral(resourceName: "btn-icon-mainview-torch-off")
        case .on:
            image = #imageLiteral(resourceName: "btn-icon-mainview-torch-on")
        default:
            break
        }
        
        torchButton.setImage(image, for: .normal)
    }
    
    func makeTorchButton(hidden: Bool) {
        torchButton.isHidden = hidden
    }
    
    func updateCameraRollPreview(with image: UIImage) {
        libraryLastImageView.image = image
    }
    
    func startTimer() {
        internalStartTimer()
    }
    
    func resetTimer() {
        internalResetTimer()
    }
}
