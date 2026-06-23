# Client Export Defaults

Files in this folder are client-only release inputs. They are intentionally ignored by Packwiz's normal index so server sync does not copy them into the server runtime.

`options.txt` contains the default keybind overrides exported into the Prism/Freesm `.mrpack`. It keeps only keybind lines that differ from a reset/default launcher profile, so unchanged controls, graphics, audio, chat, and other personal settings stay out of the repo.

`task pack:export-client` injects this file into the generated `.mrpack` as `client-overrides/options.txt`.
