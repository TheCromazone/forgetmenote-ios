import Foundation

/// Navigation routes mirroring the Android nav graph in
/// `ui/navigation/ImageOrganizerNavigation.kt`.
enum Route: Hashable {
    case imageDetail(imageId: String)
    case createChild(
        parentId: String,
        suggestedTitle: String?,
        rectangleOnParent: Rectangle?,
        tempPhotoPath: String?
    )
    case settings
    case help
    case v3Room(roomId: String)
    case v3Space(spaceId: String)
    case v3CreateSub(parentId: String, tempPhotoPath: String?,
                     suggestedRect: Rectangle? = nil, suggestedTitle: String? = nil)
}
