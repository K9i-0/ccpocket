// Compares what the app sends and reads (app-surface.generated.ts, extracted
// from the Dart sources) with the protocol types in parser.ts. There is no
// runtime code here: a mismatch is a type error in `tsc`, and the error text
// names the message type and the keys. See docs/protocol-contract-check.md.
import type { ClientMessage, ServerMessage } from "../parser.js";
import type { OPT_IN_SERVER_MESSAGE_TYPES } from "../websocket/shared.js";
import type {
  AppRead,
  AppSent,
  AppSupportedServerMessage,
} from "./app-surface.generated.js";

/** Every key of every variant of a union. */
type KeysOfUnion<T> = T extends unknown ? keyof T : never;

/** Keys that are present and required in every variant of a union. */
type RequiredInAll<T> = {
  [K in keyof T]-?: IsOptionalInSome<T, K> extends false ? K : never;
}[keyof T];
type IsOptionalInSome<T, K extends PropertyKey> = T extends unknown
  ? K extends keyof T
    ? {} extends Pick<T, K>
      ? true
      : false
    : true
  : never;

type ClientVariant<T> = Extract<ClientMessage, { type: T }>;
type ServerVariant<T> = Extract<ServerMessage, { type: T }>;

/** Fails to compile unless `T` is `never`; the error shows what `T` is. */
type MustBeEmpty<T extends never> = T;

// --- App → Bridge ----------------------------------------------------------

/** The app sends a message type the Bridge does not declare. */
type UnknownSentType = AppSent extends infer S
  ? S extends { type: infer T; from: infer F }
    ? [ClientVariant<T>] extends [never]
      ? { from: F; unknownType: T }
      : never
    : never
  : never;

/** The app sends a key the Bridge does not declare for that message. */
type UndeclaredSentKey = AppSent extends infer S
  ? S extends { type: infer T; from: infer F; always: infer A; sometimes: infer O }
    ? [ClientVariant<T>] extends [never]
      ? never
      : [Exclude<A | O, KeysOfUnion<ClientVariant<T>>>] extends [never]
        ? never
        : {
            from: F;
            type: T;
            undeclaredKeys: Exclude<A | O, KeysOfUnion<ClientVariant<T>>>;
          }
    : never
  : never;

/** The Bridge requires a key the app does not always send. */
type MissingRequiredSentKey = AppSent extends infer S
  ? S extends { type: infer T; from: infer F; always: infer A }
    ? [ClientVariant<T>] extends [never]
      ? never
      : [Exclude<RequiredInAll<ClientVariant<T>>, A>] extends [never]
        ? never
        : {
            from: F;
            type: T;
            notAlwaysSent: Exclude<RequiredInAll<ClientVariant<T>>, A>;
          }
    : never
  : never;

// --- Bridge → App ----------------------------------------------------------

/**
 * Server messages `ServerMessage.fromJson` deliberately does not parse.
 * - performance_mode_state: BridgeService consumes it from the raw JSON
 *   before parsing, to acknowledge a delivery revision.
 */
type ServerMessagesIgnoredByApp = "performance_mode_state";

/**
 * Keys the app still reads although this Bridge no longer sends them. They
 * are fallbacks for older Bridges on protocol 1 and go when it is retired.
 * - file_list.ignoredFiles: path list, replaced by the `ignored` flags.
 * - gallery_list.project: former name of `projectPath`.
 */
type LegacyKeysReadByApp =
  | { type: "file_list"; keys: "ignoredFiles" }
  | { type: "gallery_list"; keys: "project" };
type LegacyKeys<T> = Extract<LegacyKeysReadByApp, { type: T }>["keys"];

/** The Bridge declares a server message the app neither parses nor ignores. */
type UnhandledServerType = Exclude<
  ServerMessage["type"],
  AppRead["type"] | ServerMessagesIgnoredByApp
>;

/** The app parses a message type the Bridge does not declare. */
type UnknownReadType = Exclude<AppRead["type"], ServerMessage["type"]>;

/** The app reads a key the Bridge does not declare for that message. */
type UndeclaredReadKey = AppRead extends infer R
  ? R extends { type: infer T; required: infer Q; optional: infer O }
    ? [ServerVariant<T>] extends [never]
      ? never
      : [
            Exclude<Q | O, KeysOfUnion<ServerVariant<T>> | LegacyKeys<T>>,
          ] extends [never]
        ? never
        : {
            type: T;
            undeclaredKeys: Exclude<
              Q | O,
              KeysOfUnion<ServerVariant<T>> | LegacyKeys<T>
            >;
          }
    : never
  : never;

/** The app casts a key to a non-null type, but the Bridge may omit it. */
type NonNullReadOfOptionalKey = AppRead extends infer R
  ? R extends { type: infer T; required: infer Q }
    ? [ServerVariant<T>] extends [never]
      ? never
      : [Exclude<Q, RequiredInAll<ServerVariant<T>>>] extends [never]
        ? never
        : {
            type: T;
            mayBeAbsent: Exclude<Q, RequiredInAll<ServerVariant<T>>>;
          }
    : never
  : never;

/** An opt-in server message the app parses but does not ask for. */
type OptInNotRequested = Exclude<
  (typeof OPT_IN_SERVER_MESSAGE_TYPES)[number] & AppRead["type"],
  AppSupportedServerMessage
>;

export type ProtocolContractChecks = [
  MustBeEmpty<UnknownSentType>,
  MustBeEmpty<UndeclaredSentKey>,
  MustBeEmpty<MissingRequiredSentKey>,
  MustBeEmpty<UnhandledServerType>,
  MustBeEmpty<UnknownReadType>,
  MustBeEmpty<UndeclaredReadKey>,
  MustBeEmpty<NonNullReadOfOptionalKey>,
  MustBeEmpty<OptInNotRequested>,
];
