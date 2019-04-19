//
//  Copyright (C) 2016 Google, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import GoogleMobileAds
import UIKit

class TableViewController: UITableViewController, GADBannerViewDelegate, GADAdLoaderDelegate, DFPBannerAdLoaderDelegate, GADUnifiedNativeAdLoaderDelegate {

  // MARK: - Properties

  var tableViewItems = [AnyObject]()

    #if BANNER_ENABLED
    // GADBannerView

    var adsToLoad = [GADBannerView]()
    var loadStateForAds = [GADBannerView: Bool]()
    let adUnitID = "<PM_ME_FOR_AD_UNIT_ID>"
    let targeting = ["campaign":"test_metro_5039359401"]
    let adViewHeight = CGFloat(250)
    #else
    // GADAdLoader

    var adsToLoad = [GADAdLoader]()
    var loadStateForAds = [GADAdLoader: Bool]()
    var viewsForAds = [GADAdLoader: GADBannerView]()
    let adUnitID = "<PM_ME_FOR_AD_UNIT_ID>"
    let targeting = ["campaign":"test_metro_5039359401"]
    let adViewHeight = CGFloat(250)
    #endif

  // A banner ad is placed in the UITableView once per `adInterval`. iPads will have a
  // larger ad interval to avoid mutliple ads being on screen at the same time.
  let adInterval = UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8

  // MARK: - UIViewController methods

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UINib(nibName: "MenuItem", bundle: nil),
        forCellReuseIdentifier: "MenuItemViewCell")
    tableView.register(UINib(nibName: "BannerAd", bundle: nil),
        forCellReuseIdentifier: "BannerViewCell")

    // Allow row height to be determined dynamically while optimizing with an estimated row height.
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.estimatedRowHeight = 135

    // Load the sample data.
    addMenuItems()
    addBannerAds()
    preloadNextAd()
  }

  // MARK: - UITableView delegate methods

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView,
      heightForRowAt indexPath: IndexPath) -> CGFloat {

    #if BANNER_ENABLED
    if let tableItem = tableViewItems[indexPath.row] as? GADBannerView {
      let isAdLoaded = loadStateForAds[tableItem]
      return isAdLoaded == true ? adViewHeight : 0
    }
    #else
    if let _ = tableViewItems[indexPath.row] as? GADAdLoader {
        return adViewHeight
    }
    #endif

    return UITableViewAutomaticDimension
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableViewItems.count
  }

  override func tableView(_ tableView: UITableView,
      cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    #if BANNER_ENABLED
    guard let BannerView = tableViewItems[indexPath.row] as? GADBannerView else {
        let menuItem = tableViewItems[indexPath.row] as? MenuItem

        let reusableMenuItemCell = tableView.dequeueReusableCell(withIdentifier: "MenuItemViewCell",
                                                                 for: indexPath) as! MenuItemViewCell

        reusableMenuItemCell.nameLabel.text = menuItem?.name
        reusableMenuItemCell.descriptionLabel.text = menuItem?.description
        reusableMenuItemCell.priceLabel.text = menuItem?.price
        reusableMenuItemCell.categoryLabel.text = menuItem?.category
        reusableMenuItemCell.photoView.image = menuItem?.photo

        return reusableMenuItemCell
    }
    #else
    guard let loader = tableViewItems[indexPath.row] as? GADAdLoader, let BannerView = viewsForAds[loader] else {
        let menuItem = tableViewItems[indexPath.row] as? MenuItem

        let reusableMenuItemCell = tableView.dequeueReusableCell(withIdentifier: "MenuItemViewCell",
                                                                 for: indexPath) as! MenuItemViewCell

        reusableMenuItemCell.nameLabel.text = menuItem?.name
        reusableMenuItemCell.descriptionLabel.text = menuItem?.description
        reusableMenuItemCell.priceLabel.text = menuItem?.price
        reusableMenuItemCell.categoryLabel.text = menuItem?.category
        reusableMenuItemCell.photoView.image = menuItem?.photo

        return reusableMenuItemCell
    }
    #endif

      let reusableAdCell = tableView.dequeueReusableCell(withIdentifier: "BannerViewCell",
          for: indexPath)

      // Remove previous GADBannerView from the content view before adding a new one.
      for subview in reusableAdCell.contentView.subviews {
        subview.removeFromSuperview()
      }

      reusableAdCell.contentView.addSubview(BannerView)
      // Center GADBannerView in the table cell's content view.
      BannerView.center = reusableAdCell.contentView.center

      return reusableAdCell

  }

  // MARK: - GADBannerView delegate methods

  func adViewDidReceiveAd(_ adView: GADBannerView) {
    // Mark ad as succesfully loaded.
    #if BANNER_ENABLED
    loadStateForAds[adView] = true
    #endif
    // Load the next ad in the adsToLoad list.
    preloadNextAd()
  }

  func adView(_ adView: GADBannerView,
      didFailToReceiveAdWithError error: GADRequestError) {
    print("Failed to receive ad: \(error.localizedDescription)")
    // Load the next ad in the adsToLoad list.
    preloadNextAd()
  }

  // MARK: - GADAdLoader delegate methods

    func validBannerSizes(for adLoader: GADAdLoader) -> [NSValue] {
        return [NSValueFromGADAdSize(GADAdSizeFromCGSize(CGSize(width: 300, height: adViewHeight)))]
    }

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: GADRequestError) {
        print("Failed to receive ad: \(error.localizedDescription)")
        // Load the next ad in the adsToLoad list.
        preloadNextAd()
    }

    func adLoader(_ adLoader: GADAdLoader, didReceive bannerView: DFPBannerView) {
        // Mark ad as succesfully loaded.
        #if !BANNER_ENABLED
        loadStateForAds[adLoader] = true
        viewsForAds[adLoader] = bannerView
        tableView.reloadData()
        #endif
        // Load the next ad in the adsToLoad list.
        preloadNextAd()
    }

    func adLoaderDidFinishLoading(_ adLoader: GADAdLoader) {}
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADUnifiedNativeAd) {}

  // MARK: - UITableView source data generation

  /// Adds banner ads to the tableViewItems list.
  func addBannerAds() {
    var index = adInterval
    // Ensure subview layout has been performed before accessing subview sizes.
    tableView.layoutIfNeeded()
    while index < tableViewItems.count {

      #if BANNER_ENABLED
      let adSize = GADAdSizeFromCGSize(CGSize(width: 300, height: adViewHeight))
      let adView = GADBannerView(adSize: adSize)
      adView.adUnitID = adUnitID
      adView.rootViewController = self
      adView.delegate = self

      tableViewItems.insert(adView, at: index)
      adsToLoad.append(adView)
      loadStateForAds[adView] = false
      #else
      let adLoader = GADAdLoader(adUnitID: adUnitID, rootViewController: self, adTypes: [.dfpBanner, .unifiedNative], options: nil)
      adLoader.delegate = self

      tableViewItems.insert(adLoader, at: index)
      adsToLoad.append(adLoader)
      loadStateForAds[adLoader] = false
      #endif

      index += adInterval
    }
  }

  /// Preload banner ads sequentially. Dequeue and load next ad from `adsToLoad` list.
  func preloadNextAd() {
    if !adsToLoad.isEmpty {
      let ad = adsToLoad.removeFirst()
      let adRequest = DFPRequest()
      adRequest.customTargeting = targeting
      ad.load(adRequest)
    }
  }

  /// Adds MenuItems to the tableViewItems list.
  func addMenuItems() {
    var JSONObject: Any

    guard let path = Bundle.main.url(forResource: "menuItemsJSON",
        withExtension: "json") else {
      print("Invalid filename for JSON menu item data.")
      return
    }

    do {
      let data = try Data(contentsOf: path)
      JSONObject = try JSONSerialization.jsonObject(with: data,
          options: JSONSerialization.ReadingOptions())
    } catch {
      print("Failed to load menu item JSON data: %s", error)
      return
    }

    guard let JSONObjectArray = JSONObject as? [Any] else {
      print("Failed to cast JSONObject to [AnyObject]")
      return
    }

    for object in JSONObjectArray {
      guard let dict = object as? [String: Any],
          let menuIem = MenuItem(dictionary: dict) else {
        print("Failed to load menu item JSON data.")
        return
      }
      tableViewItems.append(menuIem)
    }
  }
}
