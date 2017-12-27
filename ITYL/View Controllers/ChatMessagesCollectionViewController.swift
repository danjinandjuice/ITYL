//
//  ChatMessagesCollectionViewController.swift
//  ITYL
//
//  Created by Daniel Jin on 12/6/17.
//  Copyright © 2017 Daniel Jin. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

private let reuseIdentifier = "Cell"

class ChatMessagesCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    private let cellId = "cellId"
    
    let cloudKitManager = CloudKitManager()
    
    var chatGroup: ChatGroup?
    
    @objc func reloadCollectionView() {
        self.collectionView?.reloadData()
    }
    
    let messageInputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        
        return view
    }()
    
    let inputTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter message"
        
        return textField
    }()
    
    lazy var sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send", for: .normal)
        let titleColor = UIColor(displayP3Red: 0, green: 137/255.0, blue: 249/255.0, alpha: 1)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        
        return button
    }()
    
    @IBAction func backToChatsButtonTapped(_ sender: Any) {
        
        performSegue(withIdentifier: "unwindToChatList", sender: self)
        
    }
    
    
    @objc func sendButtonTapped() {
        
        guard let chatGroup = chatGroup,
            let text = inputTextField.text,
            !text.isEmpty else { return }
        
        MessageController.shared.createMessageWith(messageText: text, chatGroup: chatGroup) { (success, message) in
            if !success {
                NSLog("Saving message was unsuccessful.")
                return
            } else {
                
                guard let message = message else { return }
                
                chatGroup.addToMessages(message)
                
                var item = 0
                
                if let messages = chatGroup.messages {
                    if messages.count > 0 {
                        item = messages.count - 1
                    }
                }
                
                DispatchQueue.main.async {
                    let insertionIndexPath = IndexPath(item: item, section: 0)
                    self.collectionView?.insertItems(at: [insertionIndexPath])
                    
                    self.inputTextField.text = nil
                }
            }
        }
    }
    
    @objc func sendButtonLongPressed() {
        
        
        
    }
    
    
    
    var bottomConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ChatMessagesCollectionViewController.sendButtonTapped))
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(ChatMessagesCollectionViewController.sendButtonLongPressed))
        tapGesture.numberOfTapsRequired = 1
        sendButton.addGestureRecognizer(tapGesture)
        sendButton.addGestureRecognizer(longGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCollectionView), name: Notifications.reloadChatGroupDetailCVNotification, object: nil)
        
        collectionView?.backgroundColor = UIColor.white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        
        // MARK: - Message input bar at bottom of screen
        view.addSubview(messageInputContainerView)
        view.addConstraintsWithFormat(format: "H:|-8-[v0]|", views: messageInputContainerView)
        view.addConstraintsWithFormat(format: "V:[v0(48)]", views: messageInputContainerView)
        
        bottomConstraint = NSLayoutConstraint(item: messageInputContainerView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0)
        
        view.addConstraint(bottomConstraint!)
        
        setupInputComponents()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotificiation), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotificiation), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // MARK: - Fetch messages for the chat group in core data & check/fetch messagse from CloudKit
        // Fetch chatgroups from Core Data
        guard let chatGroup = chatGroup,
            let users = chatGroup.users,
            let usersArray = Array(users) as? [User],
            let currUser = UserController.shared.currentUser,
            let subID = chatGroup.subscriptionID else { return }
        
        // Subscribe to new messages if not already
        self.cloudKitManager.publicDatabase.fetchAllSubscriptions { (subscriptions, error) in
            if let error = error {
                NSLog("Error fetching subscriptions. \(error)")
            }
            
            if let subscriptions = subscriptions, subscriptions.count > 0 {
                
                if let subscription = subscriptions.filter({ $0.subscriptionID == subID}).first {
                    
                    CKContainer.default().publicCloudDatabase.save(subscription, completionHandler: { (subscription, error) in
                        print(error?.localizedDescription ?? "No error")
                    })
                    
                    
                }
            } else {
                self.cloudKitManager.subscribeToCreationOfRecords(ofType: Keys.messageRecordType, chatGroup: chatGroup)
            }
        }
        
        let otherUser = usersArray.filter{ $0.recordIDString != currUser.recordIDString }.first
        
        navigationItem.title = otherUser?.username
        
        let chatGroupRecordIDString = chatGroup.recordIDString
        let chatGroupRecordID = CKRecordID(recordName: chatGroupRecordIDString)
        
        DispatchQueue.main.async {
            
            Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { (_) in
                
                MessageController.shared.fetchNewCKMessages(chatGroup: chatGroup, chatGroupRecordID: chatGroupRecordID)
            }
            
        }
    }
    
    @objc func handleKeyboardNotificiation(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let keyboardFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect
        
        let isKeyboardShowing = notification.name == Notification.Name.UIKeyboardWillShow
        
        bottomConstraint?.constant = isKeyboardShowing ? -keyboardFrame!.height : 0
        
        UIView.animate(withDuration: 0, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            
            self.view.layoutIfNeeded()
            
        }) { (completed) in
            
            if isKeyboardShowing {
                guard let chatGroupMsgs = self.chatGroup?.messages else { return }
                
                let lastIndex = chatGroupMsgs.count - 1
                
                if lastIndex >= 0 {
                    let indexPath = IndexPath(item: lastIndex, section: 0)
                    self.collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: true)
                }
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        inputTextField.endEditing(true)
    }
    
    func setupInputComponents() {
        
        let topBorderView = UIView()
        topBorderView.backgroundColor = UIColor(white: 0.5, alpha: 0.5)
        
        messageInputContainerView.addSubview(inputTextField)
        messageInputContainerView.addSubview(sendButton)
        messageInputContainerView.addSubview(topBorderView)
        
        messageInputContainerView.addConstraintsWithFormat(format: "H:|-8-[v0][v1(60)]|", views: inputTextField, sendButton)
        
        messageInputContainerView.addConstraintsWithFormat(format: "V:|[v0]|", views: inputTextField)
        messageInputContainerView.addConstraintsWithFormat(format: "V:|[v0]|", views: sendButton)
        
        messageInputContainerView.addConstraintsWithFormat(format: "H:|[v0]|", views: topBorderView)
        messageInputContainerView.addConstraintsWithFormat(format: "V:|[v0(0.5)]", views: topBorderView)
        
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return chatGroup?.messages?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        guard let message = chatGroup?.messages?.object(at: indexPath.row) as? Message,
            let messageSender = message.sentBy,
            let messageSenderID = messageSender.recordIDString,
            let senderProfilePhotoData = messageSender.photoData as Data? else { return UICollectionViewCell() }
        
        cell.messageTextView.text = message.messageText
        
        let profileImage = UIImage(data: senderProfilePhotoData)
        
        if let messageText = message.messageText {
            
            cell.profileImageView.image = profileImage
            let size = CGSize(width: 250, height: 1000)
            let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
            let estimatedFrame = NSString(string: messageText).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)], context: nil)
            
            if messageSenderID == UserController.shared.currentUser?.recordIDString {
                // Message is outgoing, not incoming
                cell.messageTextView.frame = CGRect(x: view.frame.width - estimatedFrame.width - 16 - 16 - 8 , y: 0, width: estimatedFrame.width + 16, height: estimatedFrame.height+20)
                cell.textBubbleView.frame = CGRect(x: view.frame.width-estimatedFrame.width - 16 - 8 - 16 - 10, y: -4, width: estimatedFrame.width + 16 + 8 + 10, height: estimatedFrame.height+20+6)
                cell.profileImageView.isHidden = true
                cell.bubbleImageView.image = ChatMessageCell.blueBubbleImage
                cell.bubbleImageView.tintColor = UIColor(red: 0, green: 137/255.0, blue: 249/255.0, alpha: 1)
                cell.messageTextView.textColor = UIColor.white
            }
            else {
                
                // Message is incoming, not outgoing
                cell.messageTextView.frame = CGRect(x: 48+8, y: 0, width: estimatedFrame.width + 16, height: estimatedFrame.height+20)
                cell.textBubbleView.frame = CGRect(x: 48 - 10, y: -4, width: estimatedFrame.width + 16 + 8 + 16, height: estimatedFrame.height+20+6)
                cell.profileImageView.isHidden = false
                cell.bubbleImageView.image = ChatMessageCell.grayBubbleImage
                cell.bubbleImageView.tintColor = UIColor(white: 0.95, alpha: 1)
                cell.messageTextView.textColor = UIColor.black
                
            }
            
        }
        
        
        //        guard let chatGroup = chatGroup,
        //            let chatGroupUsers = chatGroup.users,
        //            let chatGroupUsersArray = Array(chatGroupUsers) as? [User] else {
        //                return UICollectionViewCell()
        //        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        guard let message = chatGroup?.messages?.object(at: indexPath.row) as? Message else { return CGSize(width: view.frame.width, height: 100) }
        
        guard let messageText = message.messageText else { return CGSize(width: view.frame.width, height: 100) }
        
        let size = CGSize(width: 250, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        let estimatedFrame = NSString(string: messageText).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)], context: nil)
        
        return CGSize(width: view.frame.width, height: estimatedFrame.height + 20)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(8, 0, 0, 0)
    }
    
}

class ChatMessageCell: BaseCell {
    
    let messageTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.text = "Sample Message"
        textView.backgroundColor = UIColor.clear
        return textView
    }()
    
    let textBubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 15
        view.layer.masksToBounds = true
        return view
    }()
    
    let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 15
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    static let grayBubbleImage = UIImage(named: "bubble_gray")!.resizableImage(withCapInsets: UIEdgeInsetsMake(22, 26, 22, 26)).withRenderingMode(.alwaysTemplate)
    static let blueBubbleImage = UIImage(named: "bubble_blue")!.resizableImage(withCapInsets: UIEdgeInsetsMake(22, 26, 22, 26)).withRenderingMode(.alwaysTemplate)
    
    let bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ChatMessageCell.grayBubbleImage
        imageView.tintColor = UIColor(white: 0.90, alpha: 1)
        return imageView
    }()
    
    override func setupViews() {
        
        super.setupViews()
        
        backgroundColor = UIColor.white
        
        addSubview(textBubbleView)
        addSubview(messageTextView)
        addSubview(profileImageView)
        
        addConstraintsWithFormat(format: "H:|-8-[v0(30)]", views: profileImageView)
        addConstraintsWithFormat(format: "V:[v0(30)]|", views: profileImageView)
        
        textBubbleView.addSubview(bubbleImageView)
        textBubbleView.addConstraintsWithFormat(format: "H:|[v0]|", views: bubbleImageView)
        textBubbleView.addConstraintsWithFormat(format: "V:|[v0]|", views: bubbleImageView)
        
    }
    
}

extension UIView {
    
    func addConstraintsWithFormat(format: String, views: UIView...) {
        
        var viewsDictionary = [String: UIView]()
        for (index, view) in views.enumerated() {
            let key = "v\(index)"
            viewsDictionary[key] = view
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: format, options: NSLayoutFormatOptions(), metrics: nil, views: viewsDictionary))
    }
    
}
