import '../models/messages.dart';
import 'stream_cubit.dart';

/// Connection state stream as a Cubit.
typedef ConnectionCubit = StreamCubit<BridgeConnectionState>;

/// Currently running sessions stream as a Cubit.
typedef ActiveSessionsCubit = StreamCubit<List<SessionInfo>>;

/// Recent (historical) sessions stream as a Cubit.
typedef RecentSessionsCubit = StreamCubit<List<RecentSession>>;

/// Gallery images stream as a Cubit.
typedef GalleryCubit = StreamCubit<List<GalleryImage>>;

/// Project file paths stream (for @-mention autocomplete) as a Cubit.
/// Separate class (not typedef) to distinguish from ProjectHistoryCubit
/// in BlocProvider type resolution.
class FileListCubit extends StreamCubit<List<String>> {
  FileListCubit(super.initial, super.stream);
}

/// Project history stream as a Cubit.
/// Separate class (not typedef) to distinguish from FileListCubit
/// in BlocProvider type resolution.
class ProjectHistoryCubit extends StreamCubit<List<String>> {
  ProjectHistoryCubit(super.initial, super.stream);
}
