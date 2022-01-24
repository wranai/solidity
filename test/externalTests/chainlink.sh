#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# This file is part of solidity.
#
# solidity is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# solidity is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with solidity.  If not, see <http://www.gnu.org/licenses/>
#
# (c) 2022 solidity contributors.
#------------------------------------------------------------------------------

set -e

source scripts/common.sh
source test/externalTests/common.sh

verify_input "$@"
BINARY_TYPE="$1"
BINARY_PATH="$2"

function compile_fn { yarn compile; }
function test_fn { yarn test; }

function chainlink_test
{
    local repo="https://github.com/smartcontractkit/chainlink"
    local ref_type=branch
    local ref=develop
    local config_file="hardhat.config.ts"
    local config_var=config

    local compile_only_presets=()
    local settings_presets=(
        "${compile_only_presets[@]}"
        # TODO: Verify which presets work
        ir-no-optimize
        ir-optimize-evm-only
        ir-optimize-evm+yul
        legacy-no-optimize
        legacy-optimize-evm-only
        legacy-optimize-evm+yul
    )

    [[ $SELECTED_PRESETS != "" ]] || SELECTED_PRESETS=$(circleci_select_steps_multiarg "${settings_presets[@]}")
    print_presets_or_exit "$SELECTED_PRESETS"

    setup_solc "$DIR" "$BINARY_TYPE" "$BINARY_PATH"
    download_project "$repo" "$ref_type" "$ref" "$DIR"

    pushd "contracts/"

    # The project contains contracts for multiple Solidity versions. We're interested only the latest ones.
    # 0.8 tests depend on some files from earlier versions though so we can't just remove everything.
    rm -r test/v0.6/ test/v0.7/
    find src/v0.4/ -type f \
        ! -path src/v0.4/LinkToken.sol \
        ! -path src/v0.4/ERC677Token.sol \
        ! -path src/v0.4/interfaces/ERC20.sol \
        ! -path src/v0.4/interfaces/ERC20Basic.sol \
        ! -path src/v0.4/interfaces/ERC677.sol \
        ! -path src/v0.4/interfaces/ERC677Receiver.sol \
        ! -path src/v0.4/vendor/BasicToken.sol \
        ! -path src/v0.4/vendor/SafeMathChainlink.sol \
        ! -path src/v0.4/vendor/StandardToken.sol \
        -exec rm {} \;
    find src/v0.5/ -type f \
        ! -path src/v0.5/tests/GetterSetter.sol \
        -exec rm {} \;
    find src/v0.6/ -type f \
        ! -path src/v0.6/tests/EmptyOracle.sol \
        ! -path src/v0.6/interfaces/ChainlinkRequestInterface.sol \
        ! -path src/v0.6/interfaces/OracleInterface.sol \
        -exec rm {} \;
    find src/v0.7/ -type f \
        ! -path src/v0.7/AuthorizedReceiver.sol \
        ! -path src/v0.7/LinkTokenReceiver.sol \
        ! -path src/v0.7/ConfirmedOwner.sol \
        ! -path src/v0.7/ConfirmedOwnerWithProposal.sol \
        ! -path src/v0.7/Operator.sol \
        ! -path src/v0.7/interfaces/AuthorizedReceiverInterface.sol \
        ! -path src/v0.7/interfaces/ChainlinkRequestInterface.sol \
        ! -path src/v0.7/interfaces/LinkTokenInterface.sol \
        ! -path src/v0.7/interfaces/OperatorInterface.sol \
        ! -path src/v0.7/interfaces/OracleInterface.sol \
        ! -path src/v0.7/interfaces/OwnableInterface.sol \
        ! -path src/v0.7/interfaces/WithdrawalInterface.sol \
        ! -path src/v0.7/vendor/Address.sol \
        ! -path src/v0.7/vendor/SafeMathChainlink.sol \
        -exec rm {} \;

    # The older code needs some patching for the latest compiler.
    sed -i 's|constant returns|pure returns|g' src/v0.4/interfaces/ERC20.sol
    sed -i 's|constant returns|pure returns|g' src/v0.4/interfaces/ERC20Basic.sol
    sed -i 's|constant returns|pure returns|g' src/v0.4/vendor/BasicToken.sol
    sed -i 's|constant returns|pure returns|g' src/v0.4/vendor/StandardToken.sol

    sed -i 's|function balanceOf(\([^)]*\))|function balanceOf(\1) public virtual|g' src/v0.4/interfaces/ERC20Basic.sol
    sed -i 's|function balanceOf(\([^)]*\))|function balanceOf(\1) public |g' src/v0.4/vendor/BasicToken.sol
    sed -i 's|function transfer(\([^)]*\))|function transfer(\1) public virtual|g' src/v0.4/interfaces/ERC20Basic.sol
    sed -i 's|function transfer(\([^)]*\))|function transfer(\1) public|g' src/v0.4/vendor/BasicToken.sol
    sed -i 's|function allowance(\([^)]*\))|function allowance(\1) public virtual|g' src/v0.4/interfaces/ERC20.sol
    sed -i 's|function allowance(\([^)]*\))|function allowance(\1) public|g' src/v0.4/vendor/StandardToken.sol
    sed -i 's|function transferFrom(\([^)]*\))|function transferFrom(\1) public virtual|g' src/v0.4/interfaces/ERC20.sol
    sed -i 's|function transferFrom(\([^)]*\))|function transferFrom(\1) public|g' src/v0.4/vendor/StandardToken.sol
    sed -i 's|function approve(\([^)]*\))|function approve(\1) public virtual|g' src/v0.4/interfaces/ERC20.sol
    sed -i 's|function approve(\([^)]*\))|function approve(\1) public|g' src/v0.4/vendor/StandardToken.sol
    sed -i 's|function increaseApproval (\([^)]*\))|function increaseApproval (\1) public virtual|g' src/v0.4/vendor/StandardToken.sol
    sed -i 's|function decreaseApproval (\([^)]*\))|function decreaseApproval (\1) public|g' src/v0.4/vendor/StandardToken.sol

    sed -i 's|onTokenTransfer(\([^)]*\), bytes _data)|onTokenTransfer(\1, bytes memory _data) public|g' src/v0.4/interfaces/ERC677Receiver.sol
    sed -i 's|transferAndCall(\([^)]*\), bytes data)|transferAndCall(\1, bytes memory data) public|g' src/v0.4/interfaces/ERC677.sol
    sed -i 's|transferAndCall(\([^)]*\), bytes _data)|transferAndCall(\1, bytes memory _data)|g' src/v0.4/ERC677Token.sol
    sed -i 's|contractFallback(\([^)]*\), bytes _data)|contractFallback(\1, bytes memory _data)|g' src/v0.4/ERC677Token.sol
    sed -i 's|transferAndCall(\([^)]*\), bytes _data)|transferAndCall(\1, bytes memory _data)|g' src/v0.4/LinkToken.sol

    sed -i 's|TargetsUpdatedAuthorizedSenders(\([^)]*\));|emit TargetsUpdatedAuthorizedSenders(\1);|g' src/v0.7/Operator.sol
    sed -i 's|var _allowance =|uint _allowance =|g' src/v0.4/vendor/StandardToken.sol
    sed -i 's|function LinkToken()|constructor()|g' src/v0.4/LinkToken.sol
    sed -i 's|uint256 public totalSupply;|function totalSupply() external virtual returns (uint256);|g' src/v0.4/interfaces/ERC20Basic.sol

    # TODO: Still needs more patching...

    neutralize_package_lock
    neutralize_package_json_hooks
    name_hardhat_default_export "$config_file" "$config_var"
    force_hardhat_compiler_binary "$config_file" "$BINARY_TYPE" "$BINARY_PATH"
    force_hardhat_compiler_settings "$config_file" "$(first_word "$SELECTED_PRESETS")" "$config_var"
    yarn install

    replace_version_pragmas

    for preset in $SELECTED_PRESETS; do
        hardhat_run_test "$config_file" "$preset" "${compile_only_presets[*]}" compile_fn test_fn "$config_var"
    done

    popd
}

external_test Chainlink chainlink_test
