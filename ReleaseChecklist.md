## Checklist for making a release:

### Requirements
 - [ ] Lauchpad (Ubuntu One) account
 - [ ] gnupg key (has to be version 1, gpg2 won't work) for `your-name@ethereum.org` created and uploaded
 - [ ] Readthedocs account, access to the Solidity project
 - [ ] Write access to https://github.com/ethereum/homebrew-ethereum

### Documentation check
 - [ ] Run `make linkcheck` from within `docs/` and fix any broken links it finds. Ignore false positives caused by `href` anchors and dummy links not meant to work.

### Blog Post
 - [ ] Create a post on https://github.com/ethereum/solidity-blog and explain some of the new features or concepts.

### Changelog
 - [ ] Sort the changelog entries alphabetically and correct any errors you notice.
 - [ ] Create a commit on a new branch that updates the ``Changelog`` to include a release date.
 - [ ] Run ``./scripts/tests.sh`` to update the bug list.
 - [ ] Create a pull request and wait for the tests, merge it.

### Create the Release
 - [ ] Create Github release page: https://github.com/ethereum/solidity/releases/new
 - [ ] On the release page, select the ``develop`` branch as new target and set tag to the new version (e.g. `v0.8.5`) (make sure you only `SAVE DRAFT` instead of `PUBLISH RELEASE` before the actual release)
 - [ ] Thank voluntary contributors in the Github release page (use ``git shortlog -s -n -e v0.5.3..origin/develop``).
 - [ ] Check that all tests on the latest commit in ``develop`` are green.
 - [ ] Click the `PUBLISH RELEASE` button on the release page, creating the tag.
 - [ ] Wait for the CI runs on the tag itself.

### Download and Publish Binaries
 - [ ] Take the ``github/`` directory from ``b_release_binaries`` run of the tagged commit in circle-ci and add all binaries from it to the release page.
   Make sure it contains four binaries: ``solc-windows.exe``, ``solc-macos``, ``solc-static-linux`` and ``soljson.js``.
 - [ ] Take the ``solc-bin/`` directory from ``b_release_binaries`` run of the tagged commit in circle-ci and add all binaries from it to solc-bin.
 - [ ] Run ``./update --reuse-hashes`` in ``solc-bin`` and verify that the script has updated ``list.js``, ``list.txt`` and ``list.json`` files correctly and that symlinks to the new release have been added in ``solc-bin/wasm/`` and ``solc-bin/emscripten-wasm32/``.
 - [ ] Create a pull request in solc-bin and merge.

### Homebrew and MacOS
 - [ ] Update the version and the hash (``sha256sum solidity_$VERSION.tar.gz``) in https://github.com/Homebrew/homebrew-core/blob/master/Formula/solidity.rb
 - [ ] Update the version and the hash (``sha256sum solidity_$VERSION.tar.gz``) in https://github.com/ethereum/homebrew-ethereum/blob/master/solidity.rb

### Docker
 - [ ] Run ``./scripts/docker_deploy_manual.sh v$VERSION``).

### PPA
 - [ ] Change ``scripts/release_ppa.sh`` to match your key's email and key id.
 - [ ] Run ``scripts/release_ppa.sh v$VERSION`` to create the PPA release (you need the relevant openssl key).
 - [ ] Wait for the ``~ethereum/ubuntu/ethereum-static`` PPA build to be finished and published for *all platforms*. SERIOUSLY: DO NOT PROCEED EARLIER!!! *After* the static builds are *published*, copy the static package to the ``~ethereum/ubuntu/ethereum`` PPA for the destination series ``Trusty``, ``Xenial`` and ``Bionic`` while selecting ``Copy existing binaries``.

### Documentation
 - [ ] Build the new version on https://readthedocs.org/projects/solidity/ (select `latest` at the bottom of the page and click `BUILD`).
 - [ ] In the admin panel, select `Versions` in the menu and set the default version to the released one.

### Release solc-js
 - [ ] Wait until solc-bin was properly deployed. You can test this via remix - a test run through remix is advisable anyway.
 - [ ] Increment the version number, create a pull request for that, merge it after tests succeeded.
 - [ ] Run ``node verifyVersion.js && npm publish`` in the updated ``solc-js`` repository.
 - [ ] Create a tag using ``git tag --annotate v$VERSION`` and push it with ``git push --tags``.

### Post-release
 - [ ] Publish the blog post.
 - [ ] Create a commit to increase the version number on ``develop`` in ``CMakeLists.txt`` and add a new skeleton changelog entry.
 - [ ] Announce on Twitter, including links to the release and the blog post.
 - [ ] Share announcement on Reddit and Solidity forum.
 - [ ] Update the release information section on [soliditylang.org](https://github.com/ethereum/solidity-portal).
 - [ ] Lean back, wait for bug reports and repeat from step 1 :)
