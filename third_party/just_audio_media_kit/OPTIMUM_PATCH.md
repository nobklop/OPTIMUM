# OPTIMUM compatibility patch

Upstream: Pato05/just_audio_media_kit, pub.dev 2.1.0, license preserved in LICENSE.
This directory contains the original runtime sources, manifest and README.
Local version: 2.1.0+optimum.1. No changes to the global Pub cache.

`lib/mediakit_player.dart`: PlayerConfiguration.osc=true leaves mpv's OSC setting
alone, avoiding media_kit's unsupported `osc=no` write on the audio-only binary.
The ready callback disables disk demux caching before the first load, retaining
the configured bounded memory buffer. This avoids the observed Windows
`lavf: Failed to create file cache` error. Initialization errors propagate.
Logs are not filtered or silenced. Revalidate/remove this patch on upstream updates.

Validation: real Windows integration test must decode, pause, seek, switch tracks
and report missing-file errors, with neither of these two mpv errors in the log.
