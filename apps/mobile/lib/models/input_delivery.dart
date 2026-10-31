/// How a message sent while the agent is working is delivered.
enum InputDelivery {
  /// Inject the message into the running turn without interrupting it.
  steer('steer'),

  /// Hold the message and send it when the current turn ends.
  queue('queue');

  final String value;
  const InputDelivery(this.value);

  InputDelivery get other =>
      this == InputDelivery.steer ? InputDelivery.queue : InputDelivery.steer;

  static InputDelivery? fromValue(String? value) {
    for (final delivery in values) {
      if (delivery.value == value) return delivery;
    }
    return null;
  }
}
