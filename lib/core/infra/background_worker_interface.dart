abstract class IBackgroundWorker<T_in, T_out> {
  Future<void> init();
  void dispose();
}
