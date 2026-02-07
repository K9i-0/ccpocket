import '../models/messages.dart';
import '../services/bridge_service.dart';
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
typedef FileListCubit = StreamCubit<List<String>>;

/// Project history stream as a Cubit.
typedef ProjectHistoryCubit = StreamCubit<List<String>>;
