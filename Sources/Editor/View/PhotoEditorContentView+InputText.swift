//
//  PhotoEditorContentView+InputText.swift
//  AnyImageKit
//
//  Created by 蒋惠 on 2019/12/10.
//  Copyright © 2019 AnyImageProject.org. All rights reserved.
//

import UIKit

// MARK: - Internal
extension PhotoEditorContentView {
    
    /// 添加一个TextView
    func addText(_ text: String, colorIdx: Int, image: UIImage) {
        if text.isEmpty { return }
        let scale = scrollView.zoomScale
        let inset: CGFloat = 10
        let size = CGSize(width: (image.size.width + inset * 2) / scale, height: (image.size.height + inset * 2) / scale)
        
        var x: CGFloat
        var y: CGFloat
        if !didCrop {
            x = (imageView.frame.width - size.width) / 2
            y = (imageView.frame.height - size.height) / 2
        } else {
            let width = cropRealRect.width * imageView.bounds.width / imageView.frame.width
            x = abs(imageView.frame.origin.x) / scale
            x = x + (width - size.width) / 2
            
            var height = cropRealRect.height * imageView.bounds.height / imageView.frame.height
            let screenHeight = UIScreen.main.bounds.height / scale
            height = height > screenHeight ? screenHeight : height
            y = lastCropData.contentOffset.y / scale
            y = y + scrollView.contentOffset.y / scale
            y = y + (height - size.height) / 2
        }
        let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        let textView = TextImageView(frame: frame, text: text, colorIdx: colorIdx, image: image, inset: inset / scale)
        textView.contentMode = .center
        imageView.addSubview(textView)
        textImageViews.append(textView)
        addTextGestureRecognizer(textView)
    }
    
    /// 删除隐藏的TextView
    func removeHiddenTextView() {
        for (idx, textView) in textImageViews.enumerated() {
            if textView.isHidden {
                textImageViews.remove(at: idx)
            }
        }
    }
    
    /// 显示所有TextView
    func restoreHiddenTextView() {
        textImageViews.forEach{ $0.isHidden = false }
    }
    
    /// 隐藏所有TextView
    func hiddenAllTextView() {
        textImageViews.forEach{ $0.isHidden = true }
    }
    
    /// 取消激活所有TextView
    func deactivateAllTextView() {
        textImageViews.forEach{ $0.setActive(false) }
    }
}

extension PhotoEditorContentView {
    
    /// 添加手势
    private func addTextGestureRecognizer(_ textView: TextImageView) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTextSingleTap(_:)))
        let pen = UIPanGestureRecognizer(target: self, action: #selector(onTextPan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onTextPinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(onTextRotation(_:)))
        tap.delegate = self
        pen.delegate = self
        pinch.delegate = self
        rotation.delegate = self
        textView.addGestureRecognizer(tap)
        textView.addGestureRecognizer(pen)
        textView.addGestureRecognizer(pinch)
        textView.addGestureRecognizer(rotation)
    }
    
    /// 允许开始响应手势
    private func shouldBeginGesture(in textView: TextImageView) -> Bool {
        if textView.isActive { return true }
        for view in textImageViews {
            if !view.isGestureEnded {
                return false
            }
        }
        return true
    }
    
    /// 激活视图
    @discardableResult
    private func activeTextViewIfPossible(_ textView: TextImageView) -> Bool {
        if !shouldBeginGesture(in: textView) { return false }
        for view in textImageViews {
            view.setActive(view == textView)
            if view == textView {
                imageView.bringSubviewToFront(textView)
            }
        }
        return true
    }
}

// MARK: - Target
extension PhotoEditorContentView {
    
    /// 单击手势
    @objc private func onTextSingleTap(_ tap: UITapGestureRecognizer) {
        guard let textView = tap.view as? TextImageView else { return }
        if !shouldBeginGesture(in: textView) { return }
        if !textView.isActive {
            activeTextViewIfPossible(textView)
        } else {
            // 隐藏当前TextView，进入编辑页面
            textView.isHidden = true
            delegate?.inputTextWillBeginEdit(textView.text, colorIdx: textView.colorIdx)
        }
    }
    
    /// 拖拽手势
    @objc private func onTextPan(_ pan: UIPanGestureRecognizer) {
        guard let textView = pan.view as? TextImageView else { return }
        guard activeTextViewIfPossible(textView) else { return }
        
        let scale = scrollView.zoomScale
        let point = pan.translation(in: self)
        textView.point = CGPoint(x: textView.point.x + point.x / scale, y: textView.point.y + point.y / scale)
        textView.transform = textView.calculateTransform()
        pan.setTranslation(.zero, in: self)
    }
    
    /// 捏合手势
    @objc private func onTextPinch(_ pinch: UIPinchGestureRecognizer) {
        guard let textView = pinch.view as? TextImageView else { return }
        guard activeTextViewIfPossible(textView) else { return }
        
        let scale = textView.scale + (pinch.scale - 1.0)
        if scale < textView.scale || textView.frame.width < imageView.bounds.width*2.0 {
            textView.scale = scale
            textView.transform = textView.calculateTransform()
        }
        pinch.scale = 1.0
    }
    
    /// 旋转手势
    @objc private func onTextRotation(_ rotation: UIRotationGestureRecognizer) {
        guard let textView = rotation.view as? TextImageView else { return }
        guard activeTextViewIfPossible(textView) else { print(1); return }
        
        textView.rotation += rotation.rotation
        textView.transform = textView.calculateTransform()
        rotation.rotation = 0.0
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PhotoEditorContentView: UIGestureRecognizerDelegate {
    
    /// 允许多个手势同时响应
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view as? TextImageView,
            let otherView = otherGestureRecognizer.view as? TextImageView
            else { return false }
        guard view == otherView, view.isActive else { return false }
        return true
    }
}
