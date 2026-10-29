import UIKit

/// Hiding the system navigation bar (docs/decisions/0022) also turns off the edge swipe that goes back. Taking over
/// the gesture's delegate brings it back on every pushed page; on the first page of a stack it does nothing (#100).
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
