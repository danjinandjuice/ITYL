//
//  ChatGroupListTableViewController.swift
//  ITYL
//
//  Created by Daniel Jin on 10/25/17.
//  Copyright © 2017 Daniel Jin. All rights reserved.
//

import UIKit

class ChatGroupListTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - IBActions
    @IBAction func addChatGroupButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: Keys.toAddChatGroupVCSegue, sender: self)
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("\(ChatGroupController.shared.chatGroups.count) rows in section")
        return ChatGroupController.shared.chatGroups.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Keys.chatGroupCellIdentifier, for: indexPath)

        let chatGroup = ChatGroupController.shared.chatGroups[indexPath.row]
        cell.textLabel?.text = chatGroup.chatGroupName
        
        return cell
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }

    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toChatGroupMessagesSegue" {
            
            // Set segue destination as the Messages VC
            guard let chatGroupDetailVC = segue.destination as? ChatGroupMessagesTableViewController,
                let indexPath = tableView.indexPathForSelectedRow else { return }
            
            let chatGroup = ChatGroupController.shared.chatGroups[indexPath.row]
            
            // Send over the chatGroup to the detail VC
            chatGroupDetailVC.chatGroup = chatGroup
        }
    }
}
