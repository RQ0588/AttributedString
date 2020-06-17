//
//  UILabelExtension.swift
//  ┌─┐      ┌───────┐ ┌───────┐
//  │ │      │ ┌─────┘ │ ┌─────┘
//  │ │      │ └─────┐ │ └─────┐
//  │ │      │ ┌─────┘ │ ┌─────┘
//  │ └─────┐│ └─────┐ │ └─────┐
//  └───────┘└───────┘ └───────┘
//
//  Created by Lee on 2019/11/18.
//  Copyright © 2019 LEE. All rights reserved.
//

#if os(iOS) || os(tvOS)

import UIKit

private var UITapGestureRecognizerKey: Void?

extension UILabel: AttributedStringCompatible {
    
}

extension AttributedStringWrapper where Base: UILabel {

    public var text: AttributedString? {
        get { AttributedString(base.attributedText) }
        set {
            base.attributedText = newValue?.value
            
            #if os(iOS)
            if newValue?.value.contains(.action) ?? false {
                addGestureRecognizers()
                
            } else {
                removeGestureRecognizers()
            }
            #endif
        }
    }
    
    #if os(iOS)
    
    private func addGestureRecognizers() {
        defer { base.isUserInteractionEnabled = true }
        guard tap == nil else { return }
        
        let gesture = UITapGestureRecognizer(target: base, action: #selector(Base.attributedTapAction))
        base.addGestureRecognizer(gesture)
        tap = gesture
    }
    
    private func removeGestureRecognizers() {
        guard let gesture = tap else { return }
        base.removeGestureRecognizer(gesture)
        tap = nil
    }
    
    private var tap: UITapGestureRecognizer? {
        get { base.associated.get(&UITapGestureRecognizerKey) }
        set { base.associated.set(retain: &UITapGestureRecognizerKey, newValue) }
    }
    
    #endif
}

#if os(iOS)

extension UILabel {
    
    private static var attributedString: AttributedString?
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        guard let (range, action) = handleAction(touch.location(in: self)) else { return }
        // 备份原始内容
        UILabel.attributedString = attributed.text
        // 设置高亮样式
        var temp: [NSAttributedString.Key: Any] = [:]
        action.highlights.forEach { temp.merge($0.attributes, uniquingKeysWith: { $1 }) }
        self.attributedText = attributedText?.reset(range: range) { (attributes) in
            attributes.merge(temp, uniquingKeysWith: { $1 })
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let attributedString = UILabel.attributedString else {
            return
        }
        attributedText = attributedString.value
        UILabel.attributedString = nil
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let attributedString = UILabel.attributedString else {
            return
        }
        attributedText = attributedString.value
        UILabel.attributedString = nil
    }
}

fileprivate extension NSAttributedString {
    
    func reset(range: NSRange, attributes handle: (inout [NSAttributedString.Key: Any]) -> Void) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: self)
        enumerateAttributes(
            in: range,
            options: .longestEffectiveRangeNotRequired
        ) { (attributes, range, stop) in
            var temp = attributes
            handle(&temp)
            string.setAttributes(temp, range: range)
        }
        return string
    }
}

fileprivate extension UILabel {
    
    typealias ActionModel = AttributedString.ActionModel
    
    @objc
    func attributedTapAction(_ sender: UITapGestureRecognizer) {
        guard let attributedText = attributedText else { return }
        guard let (range, action) = handleAction(sender.location(in: self)) else { return }
        
        let substring = attributedText.attributedSubstring(from: range)
        if let attachment = substring.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment {
            action.callback(.init(range: range, content: .attachment(attachment)))
            
        } else {
            action.callback(.init(range: range, content: .string(substring)))
        }
    }
    
    func handleAction(_ point: CGPoint) -> (NSRange, ActionModel)? {
        guard let attributedText = attributedText else { return nil }
        // 同步Label默认样式 使用嵌入包装模式 防止原有富文本样式被覆盖
        let attributedString: AttributedString = """
        \(wrap: .embedding(.init(attributedText)), with: [.font(font), .paragraph(.alignment(textAlignment))])
        """
        
        // 构建同步Label设置的TextKit
        let textStorage = NSTextStorage(attributedString: attributedString.value)
        let textContainer = NSTextContainer(size: bounds.size)
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineBreakMode = lineBreakMode
        textContainer.lineFragmentPadding = 0.0
        textContainer.maximumNumberOfLines = numberOfLines
        
        // 获取文本所占高度
        let height = layoutManager.usedRect(for: textContainer).height
        
        // 获取点击坐标 并排除各种偏移
        var point = point
        point.y -= (bounds.height - height) / 2
        
        // 获取字形下标
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        // 获取字符下标
        let index = layoutManager.characterIndexForGlyph(at: glyphIndex)
        // 通过字形距离判断是否在字形范围内
        guard fraction > 0, fraction < 1 else {
            return nil
        }
        // 获取点击的字符串范围和回调事件
        var range = NSRange()
        guard let action = attributedString.value.attribute(.action, at: index, effectiveRange: &range) as? ActionModel else {
            return nil
        }
        return (range, action)
    }
}

#endif

#endif
