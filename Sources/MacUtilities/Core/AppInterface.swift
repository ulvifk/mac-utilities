/// What the user sees of the app itself: the menu bar item, its popover and the settings window. Every view in it observes the controller, and
/// the settings window shows whether the event tap runs, so the controller launches it once the features and the tap run and hands itself in
/// then.
protocol AppInterface {
    func launch(controller: AppController)

    /// Brings the settings window to the front on the General pane, for something the user must act on there.
    func openGeneralSettings()
}
