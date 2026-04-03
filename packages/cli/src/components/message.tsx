import React from "react";
import { Text } from "ink";
import { renderMessage } from "../renderer.js";

interface MessageProps {
  msg: Record<string, unknown>;
}

export function Message({ msg }: MessageProps) {
  const rendered = renderMessage(msg);
  if (!rendered) return null;
  return <Text>{rendered}</Text>;
}
