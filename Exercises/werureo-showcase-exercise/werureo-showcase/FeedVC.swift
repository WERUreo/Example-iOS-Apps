//
//  FeedVC.swift
//  werureo-showcase
//
//  Created by Keli'i Martin on 3/14/16.
//  Copyright © 2016 WERUreo. All rights reserved.
//

import UIKit
import Firebase
import Alamofire

class FeedVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var postField: MaterialTextField!
    @IBOutlet weak var imageSelectorImage: UIImageView!

    var posts = [Post]()
    var imageSelected = false
    var imagePicker: UIImagePickerController!

    static var imageCache = NSCache()

    ////////////////////////////////////////////////////////////

    override func viewDidLoad()
    {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        tableView.estimatedRowHeight = 358
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self

        DataService.ds.REF_POSTS.observeEventType(.Value, withBlock: { snapshot in
            self.posts = []

            if let snapshots = snapshot.children.allObjects as? [FIRDataSnapshot]
            {
                for snap in snapshots
                {
                    if let postDict = snap.value as? [String : AnyObject]
                    {
                        let key = snap.key
                        let post = Post(postKey: key, dictionary: postDict)
                        self.posts.append(post)
                    }
                }

                self.tableView.reloadData()
            }
        })
    }

    ////////////////////////////////////////////////////////////
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }

    ////////////////////////////////////////////////////////////

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return posts.count
    }

    ////////////////////////////////////////////////////////////

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let post = posts[indexPath.row]

        if let cell = tableView.dequeueReusableCellWithIdentifier("PostCell") as? PostCell
        {
            cell.request?.cancel()

            var img: UIImage?

            if let url = post.imageUrl
            {
                img = FeedVC.imageCache.objectForKey(url) as? UIImage
            }
            cell.configureCell(post, img: img)
            return cell
        }
        else
        {
            return PostCell()
        }
    }

    ////////////////////////////////////////////////////////////

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        let post = posts[indexPath.row]

        if post.imageUrl == nil
        {
            return 150
        }
        else
        {
            return tableView.estimatedRowHeight
        }
    }

    ////////////////////////////////////////////////////////////

    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?)
    {
        imagePicker.dismissViewControllerAnimated(true, completion: nil)
        imageSelectorImage.image = image
        imageSelected = true
    }

    ////////////////////////////////////////////////////////////

    @IBAction func selectImage(sender: UITapGestureRecognizer)
    {
        presentViewController(imagePicker, animated: true, completion: nil)
    }

    ////////////////////////////////////////////////////////////

    @IBAction func makePost(sender: AnyObject)
    {
        if let txt = postField.text where txt != ""
        {
            if let img = imageSelectorImage.image where imageSelected
            {
                let urlStr = "https://post.imageshack.us/upload_api.php"
                let url = NSURL(string: urlStr)!
                let imgData = UIImageJPEGRepresentation(img, 0.2)!
                let keyData = getImageShackAPIKey()!.dataUsingEncoding(NSUTF8StringEncoding)!
                let keyJSON = "json".dataUsingEncoding(NSUTF8StringEncoding)!

                Alamofire.upload(.POST, url, multipartFormData: { multipartFormData in
                    multipartFormData.appendBodyPart(data: imgData, name: "fileupload", fileName: "image", mimeType: "image/jpg")
                    multipartFormData.appendBodyPart(data: keyData, name: "key")
                    multipartFormData.appendBodyPart(data: keyJSON, name: "format")
                    }) { encodingResult in
                        switch encodingResult
                        {
                        case .Success(let upload, _, _):
                            upload.responseJSON(completionHandler: { response in
                                if let info = response.result.value as? [String : AnyObject],
                                let links = info["links"] as? [String : AnyObject],
                                let imgLink = links["image_link"] as? String
                                {
                                    self.postToFirebase(imgLink)
                                }
                            })
                        case .Failure(let error):
                            print(error)
                        }
                }
            }
            else
            {
                self.postToFirebase(nil)
            }
        }
    }

    ////////////////////////////////////////////////////////////

    func postToFirebase(imgUrl: String?)
    {
        var post: [String : AnyObject] =
        [
            "description" : postField.text!,
            "likes" : 0
        ]

        if let url = imgUrl
        {
            post["imageUrl"] = url
        }

        let firebasePost = DataService.ds.REF_POSTS.childByAutoId()
        firebasePost.setValue(post)

        postField.text = ""
        imageSelectorImage.image = UIImage(named: "camera")
        imageSelected = false

        tableView.reloadData()
    }
}
