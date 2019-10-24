//
//  CommentsViewController.swift
//  ToDoList
//
//  Created by Radu Ursache on 22/02/2019.
//  Copyright © 2019 Radu Ursache. All rights reserved.
//

import UIKit
import RSTextViewMaster
import UnderKeyboard
import SafariServices

class CommentsViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var inputContainerView: UIView!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var textView: RSTextViewMaster!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    let keyboardObserver = UnderKeyboardObserver()
    
    var onCompletion: (() -> Void)?
    
    var currentTask = TaskModel()
    var showKeyboardAtLoad = false
    var currentEditingComment = CommentModel()
    var editMode = false
    var keyboardVisible = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.showKeyboardAtLoad {
            self.textView.becomeFirstResponder()
        }
    }
    
    override func setupUI() {
        super.setupUI()
        
        self.title = "COMMENTS_TITLE".localized()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "CLOSE".localized(), style: .done, target: self, action: #selector(self.closeAction))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.itemWith(colorfulImage: UIImage(named: "keyboardIcon")!, target: self, action: #selector(self.keyboardButtonAction))
        
        self.addButton.addTarget(self, action: #selector(self.addCommentAction), for: .touchUpInside)
        
        self.textView.text = ""
        self.textView.delegate = self
        self.textView.placeHolder = "COMMENTS_ADD_COMMENT".localized()
        self.textView.isAnimate = true
        self.textView.maxHeight = self.textView.frame.height * 3
        
        Utils().themeView(view: self.addButton)
        
        self.tableView.estimatedRowHeight = 60
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))
    }
    
    override func setupBindings() {
        super.setupBindings()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.keyboardObserver.start()
        self.keyboardObserver.willAnimateKeyboard = { height in
            self.keyboardVisible = true
            self.bottomConstraint.constant = height - (UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0)
        }
        self.keyboardObserver.animateKeyboard = { height in
            self.inputContainerView.layoutIfNeeded()
        }
    }
    
    @objc func closeAction() {
        self.onCompletion?()
        
        self.textView.resignFirstResponder()
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func addCommentAction() {
        if self.editMode {
            self.editMode = false
            
            self.addButton.setTitle("ADD".localized(), for: .normal)
            
            RealmManager.sharedInstance.changeCommentContent(comment: self.currentEditingComment, content: self.textView.text)
        } else {
            let newComment = CommentModel(title: self.textView.text, date: Date())
            newComment.setTask(task: self.currentTask)
            
            RealmManager.sharedInstance.addComment(comment: newComment)
        }
        
        self.tableView.reloadData()
        self.scrollToBottom()
        
        self.textView.text = ""
    }
    
    func startEditMode() {
        self.editMode = true
        
        self.textView.setText(text: self.currentEditingComment.content)
        self.textView.layoutIfNeeded()
        self.textView.becomeFirstResponder()
        
        self.addButton.setTitle("UPDATE".localized(), for: .normal)
    }
    
    func deleteComment(comment: CommentModel) {
        RealmManager.sharedInstance.deleteComment(comment: comment, soft: true)
        
        self.tableView.reloadData()
    }
    
    func openURL(url: URL) {
        let currentOption = UserDefaults.standard.integer(forKey: Config.UserDefaults.openLinks)
        if currentOption == 0 {
            let safariVC = SFSafariViewController(url: url)
            self.present(safariVC, animated: true, completion: nil)
        } else if currentOption == 1 {
            UIApplication.shared.open(url, options: [:])
        }
    }
    
    func openHashtag(hashtag: String) {
//        self.showOK(title: "Hashtag".localized(), message: hashtag)
    }
    
    @objc func keyboardButtonAction() {
        if self.keyboardVisible {
            self.keyboardVisible = false
            self.textView.resignFirstResponder()
            self.bottomConstraint.constant = 0
            
        } else {
            self.textView.becomeFirstResponder()
        }
        
        self.scrollToBottom()
    }
    
    func scrollToBottom() {
        if self.currentTask.availableComments().count > 1 {
            self.tableView.scrollToRow(at: IndexPath(row: self.currentTask.availableComments().count-1, section: 0), at: .bottom, animated: true)
        }
    }
}

extension CommentsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.currentTask.availableComments().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommentTableViewCell.getIdentifier(), for: indexPath) as! CommentTableViewCell
        
        let currentItem = self.currentTask.availableComments()[indexPath.row]
        
        cell.dateLabel.text = Config.General.dateFormatter().string(from: currentItem.date as Date)
        cell.contentLabel.text = currentItem.content
        
        cell.contentLabel.handleURLTap { (url) in
            self.openURL(url: url)
        }
        
        cell.contentLabel.handleHashtagTap { (hashtag) in
            self.openHashtag(hashtag: hashtag)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.currentEditingComment = self.currentTask.availableComments()[indexPath.row]
        
        self.startEditMode()
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "DELETE".localized()) { (_, indexPath) in
            guard indexPath.row < self.currentTask.availableComments().count else { return }
            let comment = self.currentTask.availableComments()[indexPath.row]
            
            self.deleteComment(comment: comment)
        }
        return [deleteAction]
    }
}

extension CommentsViewController: RSTextViewMasterDelegate, UITextViewDelegate {
    func growingTextView(growingTextView: RSTextViewMaster, willChangeHeight height: CGFloat) {
        self.view.layoutIfNeeded()
    }
    
    func growingTextView(growingTextView: RSTextViewMaster, didChangeHeight height: CGFloat) {
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.scrollToBottom()
        }
    }
}
