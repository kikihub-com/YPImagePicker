//
//  YPLibraryView.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 2015/11/14.
//  Copyright © 2015 Yummypets. All rights reserved.
//

import UIKit
import Stevia
import Photos

internal final class YPLibraryView: UIView {

    // MARK: - Public vars

    internal let assetZoomableViewMinimalVisibleHeight: CGFloat  = 50
    internal var assetViewContainerConstraintTop: NSLayoutConstraint?
    internal let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let v = UICollectionView(frame: .zero, collectionViewLayout: layout)
        v.backgroundColor = YPConfig.colors.libraryScreenBackgroundColor
        v.collectionViewLayout = layout
        v.showsHorizontalScrollIndicator = false
        v.alwaysBounceVertical = true
        return v
    }()
    internal lazy var assetViewContainer: YPAssetViewContainer = {
        let v = YPAssetViewContainer(frame: .zero, zoomableView: assetZoomableView)
        v.accessibilityIdentifier = "assetViewContainer"
        return v
    }()
    internal let assetZoomableView: YPAssetZoomableView = {
        let v = YPAssetZoomableView(frame: .zero)
        v.accessibilityIdentifier = "assetZoomableView"
        return v
    }()
    /// At the bottom there is a view that is visible when selected a limit of items with multiple selection
    internal let maxNumberWarningView: UIView = {
        let v = UIView()
        v.backgroundColor = .ypSecondarySystemBackground
        v.isHidden = true
        return v
    }()
    internal let maxNumberWarningLabel: UILabel = {
        let v = UILabel()
        v.font = YPConfig.fonts.libaryWarningFont
        return v
    }()
    internal var limitAccessView: UIView?

    // MARK: - Private vars

    private let line: UIView = {
        let v = UIView()
        v.backgroundColor = .ypSystemBackground
        return v
    }()
    /// When video is processing this bar appears
    private let progressView: UIProgressView = {
        let v = UIProgressView()
        v.progressViewStyle = .bar
        v.trackTintColor = YPConfig.colors.progressBarTrackColor
        v.progressTintColor = YPConfig.colors.progressBarCompletedColor ?? YPConfig.colors.tintColor
        v.isHidden = true
        v.isUserInteractionEnabled = false
        return v
    }()
    private let collectionContainerView: UIView = {
        let v = UIView()
        v.accessibilityIdentifier = "collectionContainerView"
        return v
    }()
    private var shouldShowLoader = false {
        didSet {
            DispatchQueue.main.async {
                self.assetViewContainer.squareCropButton.isEnabled = !self.shouldShowLoader
                self.assetViewContainer.multipleSelectionButton.isEnabled = !self.shouldShowLoader
                self.assetViewContainer.spinnerIsShown = self.shouldShowLoader
                self.shouldShowLoader ? self.hideOverlayView() : ()
            }
        }
    }
    var limitAccessATapped: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("Only code layout.")
    }

    // MARK: - Public Methods

    // MARK: Overlay view

    func hideOverlayView() {
        assetViewContainer.itemOverlay?.alpha = 0
    }

    // MARK: Loader and progress

    func fadeInLoader() {
        shouldShowLoader = true
        // Only show loader if full res image takes more than 0.5s to load.
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            if self.shouldShowLoader == true {
                UIView.animate(withDuration: 0.2) {
                    self.assetViewContainer.spinnerView.alpha = 1
                }
            }
        }
    }

    func hideLoader() {
        shouldShowLoader = false
        assetViewContainer.spinnerView.alpha = 0
    }

    func updateProgress(_ progress: Float) {
        progressView.isHidden = progress > 0.99 || progress == 0
        progressView.progress = progress
        UIView.animate(withDuration: 0.1, animations: progressView.layoutIfNeeded)
    }

    // MARK: Crop Rect

    func currentCropRect() -> CGRect {
        let cropView = assetZoomableView
        let normalizedX = min(1, cropView.contentOffset.x &/ cropView.contentSize.width)
        let normalizedY = min(1, cropView.contentOffset.y &/ cropView.contentSize.height)
        let normalizedWidth = min(1, cropView.frame.width / cropView.contentSize.width)
        let normalizedHeight = min(1, cropView.frame.height / cropView.contentSize.height)
        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }

    // MARK: Curtain

    func refreshImageCurtainAlpha() {
        let imageCurtainAlpha = abs(assetViewContainerConstraintTop?.constant ?? 0)
        / (assetViewContainer.frame.height - assetZoomableViewMinimalVisibleHeight)
        assetViewContainer.curtain.alpha = imageCurtainAlpha
    }

    func cellSize() -> CGSize {
        var screenWidth = window?.windowScene?.screen.bounds.width ?? 1.0
        let scale = window?.windowScene?.screen.scale ?? 1.0
        if UIDevice.current.userInterfaceIdiom == .pad && YPImagePickerConfiguration.widthOniPad > 0 {
            screenWidth =  YPImagePickerConfiguration.widthOniPad
        }
        let size = screenWidth / 4 * scale
        return CGSize(width: size, height: size)
    }

    // MARK: - Private Methods

    private func createLimitAccessView() -> UIView {
        let limitAccessView = UIView()
        limitAccessView.overrideUserInterfaceStyle = .light

        let label = UILabel()
        label.text = ypLocalized("YPImagePickerLimitedAccessText")
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .black
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let manageButton = makeManageGlassButton()

        let stackView = UIStackView(arrangedSubviews: [label, manageButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8
        limitAccessView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.centerYAnchor.constraint(equalTo: limitAccessView.centerYAnchor).isActive = true
        stackView.leadingAnchor.constraint(equalTo: limitAccessView.leadingAnchor, constant: 16).isActive = true
        stackView.trailingAnchor.constraint(equalTo: limitAccessView.trailingAnchor, constant: -12).isActive = true

        return limitAccessView
    }

    private func makeManageGlassButton() -> UIView {
        let buttonHeight: CGFloat = 36
        let title = ypLocalized("YPImagePickerLimitedAccessButton")
        let titleTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = .systemFont(ofSize: 13, weight: .semibold)
            return updated
        }
        let insets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)

        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.title = title
            config.cornerStyle = .capsule
            config.baseForegroundColor = .black
            config.contentInsets = insets
            config.titleTextAttributesTransformer = titleTransformer

            let button = UIButton(configuration: config)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(didTapLimitAccess), for: .touchUpInside)
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            return button
        }

        // iOS 15–25: blur capsule background with the button living inside the
        // effect view's contentView so taps and styling stay coherent.
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .black
        config.contentInsets = insets
        config.titleTextAttributesTransformer = titleTransformer

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(didTapLimitAccess), for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = buttonHeight / 2
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true

        blurView.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalToConstant: buttonHeight),
            button.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor)
        ])
        blurView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        blurView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        return blurView
    }
    
    private func setupLayout() {
        limitAccessView = createLimitAccessView()
        
        guard let limitAccessView else { return }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapLimitAccess))
        limitAccessView.isUserInteractionEnabled = true
        limitAccessView.addGestureRecognizer(tap)
        limitAccessView.backgroundColor = UIColor(red: 248/255, green: 215/255, blue: 82/255, alpha: 1.0)

        subviews(
            collectionContainerView.subviews(
                collectionView
            ),
            line,
            assetViewContainer.subviews(
                assetZoomableView
            ),
            progressView,
            maxNumberWarningView.subviews(
                maxNumberWarningLabel
            ),
            limitAccessView
        )

        collectionContainerView.fillContainer()
        collectionView.fillHorizontally().bottom(0)

        assetViewContainer.Bottom == line.Top
        line.height(1)
        line.fillHorizontally()
        limitAccessView.fillHorizontally()//.bottom(0)
        limitAccessView.Bottom == collectionView.Top
        updateLimitedAccessView()
        
        assetViewContainer.top(0).fillHorizontally().heightEqualsWidth()
        self.assetViewContainerConstraintTop = assetViewContainer.topConstraint
        assetZoomableView.fillContainer().heightEqualsWidth()
        assetZoomableView.Bottom == limitAccessView.Top
        assetViewContainer.sendSubviewToBack(assetZoomableView)

        progressView.height(5).fillHorizontally()
        progressView.Bottom == line.Top

        |maxNumberWarningView|.bottom(0)
        maxNumberWarningView.Top == safeAreaLayoutGuide.Bottom - 40
        maxNumberWarningLabel.centerHorizontally().top(11)
    }
    func updateLimitedAccessView() {
        guard let limitAccessView else { return }
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if status == .limited {
                limitAccessView.isHidden = false
                if limitAccessView.heightConstraint == nil {
                    limitAccessView.height(52)
                } else {
                    limitAccessView.heightConstraint?.constant = 52
                }
            } else {
                limitAccessView.isHidden = true
                if limitAccessView.heightConstraint == nil {
                    limitAccessView.height(0)
                } else {
                    limitAccessView.heightConstraint?.constant = 0
                }
            }
        } else {
            limitAccessView.isHidden = true
            limitAccessView.height(0)
        }
        limitAccessView.setNeedsLayout()
        limitAccessView.layoutIfNeeded()
    }
    
    @objc private func didTapLimitAccess() {
        self.limitAccessATapped?()
    }
}
