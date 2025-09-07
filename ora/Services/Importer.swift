import SwiftUI

struct Root: Decodable {
    let sidebar: Sidebar
}

struct Sidebar: Decodable {
    let containers: [Container]
}

struct Container: Decodable {
    let global: Global?
    let spaces: [SpaceItem]?
    let items: [Item]?
    let topAppsContainerIDs: [TopAppsContainerID]?

    enum CodingKeys: String, CodingKey {
        case global
        case spaces
        case items
        case topAppsContainerIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        global = try container.decodeIfPresent(Global.self, forKey: .global)
        spaces = try container.decodeIfPresent([SpaceItem].self, forKey: .spaces)
        items = try container.decodeIfPresent([Item].self, forKey: .items)
        topAppsContainerIDs = try container.decodeIfPresent([TopAppsContainerID].self, forKey: .topAppsContainerIDs)
    }
}

struct Global: Decodable {}

enum SpaceItem: Decodable {
    case id(String)
    case custom(CustomInfo)

    struct CustomInfo: Decodable {
        let customInfo: IconWrapper
        let title: String?
        let id: String
        let containerIDs: [String]
    }

    struct IconWrapper: Decodable {
        let iconType: IconType
    }

    struct IconType: Decodable {
        // swiftlint:disable:next identifier_name
        let emoji_v2: String?
        let emoji: Int?
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let id = try? singleValue.decode(String.self) {
            self = .id(id)
        } else {
            self = try .custom(CustomInfo(from: decoder))
        }
    }
}

enum Item: Decodable {
    case id(String)
    case object(ItemObject)

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let id = try? singleValue.decode(String.self) {
            self = .id(id)
        } else {
            self = try .object(ItemObject(from: decoder))
        }
    }
}

struct ItemObject: Decodable {
    let id: String
    let originatingDevice: String?
    let createdAt: Double?
    let title: String?
    let data: ItemData?
    let parentID: String?
    let isUnread: Bool
    let childrenIds: [String]
}

struct ItemData: Decodable {
    let tab: TabData?
    let easel: EaselData?
    let itemContainer: ItemContainerData?
}

struct TabData: Decodable {
    let savedURL: String?
    let savedTitle: String?
    let savedMuteStatus: String?
    let activeTabBeforeCreationID: String?
    let timeLastActiveAt: Double?
}

struct EaselData: Decodable {
    let creatorID: String?
    let easelID: String?
    let shareStatus: String?
    let title: String?
    let timeLastActiveAt: Double?
}

struct ItemContainerData: Decodable {
    let containerType: ContainerType?

    struct ContainerType: Decodable {
        let spaceItems: [String: String]?
        let topApps: [String: TopApp]?

        struct TopApp: Decodable {
            let `default`: [String: AnyCodable]?
        }
    }
}

struct AnyCodable: Decodable {}

enum TopAppsContainerID: Decodable {
    case id(String)
    case object(TopAppsObject)

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let id = try? singleValue.decode(String.self) {
            self = .id(id)
        } else {
            self = try .object(TopAppsObject(from: decoder))
        }
    }
}

struct TopAppsObject: Decodable {
    let id: String?
    // Add more fields as needed based on actual JSON structure
}

func getRoot() -> Root? {
//    let url = URL(fileURLWithPath: "/Users/keni/Library/Application Support/Arc/StorableSidebar.json")
    let url = URL(fileURLWithPath: NSString(string: "~/Library/Application Support/Arc/StorableSidebar.json")
        .expandingTildeInPath
    )

    do {
        let data = try Data(contentsOf: url)
        let root = try JSONDecoder().decode(Root.self, from: data)
        return root
    } catch {
        print("Decoding failed: \(error)")
        return nil
    }
}

struct CleanSpace {
    var emoji: String?
    var title: String?
    var containerIDs: Set<String>  = []
    var container: TabContainer?
}

struct CleanTab {
    var title: String
    var urlString: String
    var id: String
    var parentID: String
}

struct Result {
    var cleanSpaces: [CleanSpace]
    var cleanTabs: [CleanTab]
    var favs: Set<String> = []
}

func inspectItems(_ root: Root) -> Result {
    var cleanSpaces: [CleanSpace] = []
    var cleanTabs: [CleanTab] = []
    var topIds: [String] = []
//    print("==================")
    for (_, container) in root.sidebar.containers.enumerated() {
//        print("Container \(index):")

        // Inspect spaces

        if let spaces = container.spaces {
//            print("  has \(spaces.count) spaces")
            for item in spaces {
                switch item {
                case let .custom(customInfo):
                    var cleanSpace = CleanSpace(
                        emoji: customInfo.customInfo.iconType.emoji_v2,
                        title: customInfo.title,
                        containerIDs: []
                    )
                    for cid in customInfo.containerIDs {
                        cleanSpace.containerIDs
                            .insert(cid)
                    }
                    cleanSpace.containerIDs
                        .insert(customInfo.id)

                    cleanSpaces.append(cleanSpace)
                case let .id(id):
                    print("    Space ID: \(id)")
                }
            }
        } else {
//            print("  no spaces")
        }

        // Inspect items with detailed output
        if let items = container.items {
//            print("  has \(items.count) items")
            var idCount = 0
            var objectCount = 0
            for (itemIndex, item) in items.enumerated() {
                print("    Item \(itemIndex + 1):")
                switch item {
                case let .id(id):
                    idCount += 1
                    print("      ID: \(id)")
                case let .object(itemObject):
                    objectCount += 1
//                    print("      Object:")
//                    print("        ID: \(itemObject.id)")
//                    print("        Title: \(itemObject.title ?? "n/a")")
//                    print("        Originating Device: \(itemObject.originatingDevice ?? "n/a")")
//                    print("        Created At: \(itemObject.createdAt ?? 0)")
//                    print("        Is Unread: \(itemObject.isUnread)")
//                    print("        Parent ID: \(itemObject.parentID ?? "n/a")")
//                    print("        Children IDs: \(itemObject.childrenIds)")
                    if let data = itemObject.data {
                        if let tab = data.tab {
                            if let parentID = itemObject.parentID, let urlString = tab.savedURL {
                                cleanTabs.append(
                                    CleanTab(
                                        title: tab.savedTitle ?? "New Tab",
                                        urlString: urlString,
                                        id: itemObject.id,
                                        parentID: parentID
                                    )
                                )
                            }
//                            print("        Tab Data:")
//                            print("          Saved URL: \(tab.savedURL ?? "n/a")")
//                            print("          Saved Title: \(tab.savedTitle ?? "n/a")")
                        }
//                        if let easel = data.easel {
                        ////                            print("        Easel Data:")
                        ////                            print("          Easel ID: \(easel.easelID ?? "n/a")")
                        ////                            print("           Title: \(easel.title ?? "n/a")")
//                        }
                    } else {
//                        print("        No Data")
                    }
                }
            }
//            print("    Total: \(idCount) IDs, \(objectCount) objects")
        } else {
//            print("  no items")
        }

        // Inspect topAppsContainerIDs
        if let topApps = container.topAppsContainerIDs {
//            print("  has \(topApps.count) topAppsContainerIDs")
            for topApp in topApps {
                switch topApp {
                case let .id(id):
//                    print("    TopApp ID: \(id)")
                    topIds.append(id)
                case let .object(obj):
                    print("    TopApp Object: id=\(obj.id ?? "n/a")")
                }
            }
        } else {
//            print("  no topAppsContainerIDs")
        }
    }
    var result = Result(
        cleanSpaces: cleanSpaces,
        cleanTabs: cleanTabs
    )
    for tid in topIds {
        result.favs.insert(tid)
    }
//    return []

    return result
}
