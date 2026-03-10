abstract class IBackgroundWorker<T_in, T_out> {
  Future<void> init();
  void enqueueTask(T_in task);
  Stream<T_out> get resultStream;
  void dispose();
}
