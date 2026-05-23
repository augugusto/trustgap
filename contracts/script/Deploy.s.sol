// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/dao/GovernorDAO.sol";
import "../src/dao/EmergencyGovernor.sol";
import "../src/ens/ENSResolver.sol";
import "../src/releases/ReleaseProposal.sol";

/// @title Deploy
/// @notice Foundry forge script for deploying all contracts to Base Sepolia.
///
/// Usage:
///   source .env  # set DEPLOYER_PRIVATE_KEY, BASE_SEPOLIA_RPC_URL, etc.
///   forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify
///
/// Required env vars:
///   DEPLOYER_PRIVATE_KEY       — Deployer's private key
///   ENS_PUBLIC_RESOLVER        — ENS public resolver address on Base Sepolia
///   ENS_NODE                   — The ENS namehash (bytes32) for the managed domain
///
/// Optional env vars:
///   TIMELOCK_MIN_DELAY         — Minimum timelock delay in seconds (default: 15 days)
///   INITIAL_MEMBERS            — Comma-separated list of addresses to mint as initial members
///                                Example: "0x123...,0x456...,0x789..."
contract Deploy is Script {
    function run() external {
        // ── Read configuration ──────────────────────────────────────
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address ensPublicResolver = vm.envAddress("ENS_PUBLIC_RESOLVER");
        bytes32 ensNode = vm.envBytes32("ENS_NODE");

        uint256 timelockMinDelay = 15 days;
        if (vm.envOr("TIMELOCK_MIN_DELAY", uint256(0)) > 0) {
            timelockMinDelay = vm.envUint("TIMELOCK_MIN_DELAY");
        }

        // Read initial members (comma-separated addresses)
        address[] memory initialMembers;
        string memory initialMembersRaw = vm.envOr("INITIAL_MEMBERS", string(""));
        if (bytes(initialMembersRaw).length > 0) {
            initialMembers = _parseAddresses(initialMembersRaw);
        }

        console.log("Deployer:", deployer);
        console.log("ENS Public Resolver:", ensPublicResolver);
        console.log("ENS Node:", vm.toString(ensNode));
        console.log("Timelock Min Delay:", timelockMinDelay);
        console.log("Initial Members:", initialMembers.length);

        // ── Start broadcasting ──────────────────────────────────────
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy DAOShare (1 share = 1 member, non-transferable)
        DAOShare share = new DAOShare();
        console.log("DAOShare deployed at:", address(share));

        // 2. Deploy TimelockController
        //    Initially set deployer as sole proposer + admin.
        //    Governor gets PROPOSER+EXECUTOR roles after deployment.
        //    address(0) as executor enables anyone to execute after delay.
        address[] memory timelockProposers = new address[](1);
        timelockProposers[0] = deployer;

        address[] memory timelockExecutors = new address[](1);
        timelockExecutors[0] = address(0); // anyone can execute after delay

        TimelockController timelock = new TimelockController(
            timelockMinDelay,
            timelockProposers,
            timelockExecutors,
            deployer // admin
        );
        console.log("TimelockController deployed at:", address(timelock));

        // 3. Deploy GovernorDAO (51% quorum)
        GovernorDAO governor = new GovernorDAO(IVotes(address(share)), timelock);
        console.log("GovernorDAO deployed at:", address(governor));

        // 4. Configure Governor as proposer + executor on the Timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);

        console.log("Timelock roles configured: Governor is PROPOSER + EXECUTOR");

        // 5. Deploy EmergencyGovernor (66% supermajority quorum, canceller role only)
        EmergencyGovernor emergencyGovernor = new EmergencyGovernor(IVotes(address(share)), timelock);
        console.log("EmergencyGovernor deployed at:", address(emergencyGovernor));

        // Grant CANCELLER_ROLE on the TimelockController.
        // EmergencyGovernor does NOT get PROPOSER_ROLE or EXECUTOR_ROLE —
        // it can only cancel pending operations, not schedule new ones.
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(emergencyGovernor));
        console.log("EmergencyGovernor granted CANCELLER_ROLE on TimelockController");

        // 6. Deploy ENSResolver
        ENSResolver resolver = new ENSResolver(ensPublicResolver, ensNode);
        console.log("ENSResolver deployed at:", address(resolver));

        // Grant CALLER_ROLE to Timelock so it can call setContenthash
        resolver.grantRole(resolver.CALLER_ROLE(), address(timelock));
        resolver.revokeRole(resolver.DEFAULT_ADMIN_ROLE(), deployer);
        console.log("ENSResolver roles configured: Timelock is CALLER_ROLE");

        // 7. Deploy ReleaseProposal recorder
        ReleaseProposal recorder = new ReleaseProposal();
        console.log("ReleaseProposal deployed at:", address(recorder));

        // Grant RECORDER_ROLE to Timelock so it records releases on execution
        recorder.grantRole(recorder.RECORDER_ROLE(), address(timelock));
        recorder.revokeRole(recorder.DEFAULT_ADMIN_ROLE(), deployer);
        console.log("ReleaseProposal roles configured: Timelock is RECORDER_ROLE");

        // 8. Bootstrap: mint initial members.
        //    Deployer is currently governor on DAOShare. Mint 1 share to each
        //    initial member before transferring governance to GovernorDAO.
        if (initialMembers.length > 0) {
            for (uint256 i = 0; i < initialMembers.length; i++) {
                share.mint(initialMembers[i]);
                console.log("Minted 1 share to:", initialMembers[i]);
            }
        }

        // 9. Configure DAOShare governance.
        //    Set timelock first (needed for proposals to flow through execution),
        //    then transfer governor to GovernorDAO.
        share.setTimelock(address(timelock));
        console.log("DAOShare timelock set to TimelockController");

        share.setGovernor(address(governor));
        console.log("DAOShare governor set to GovernorDAO");

        // 10. Renounce deployer's admin role on Timelock (optional safety)
        //    Comment this out until setup is complete on testnet.
        // timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        // console.log("Timelock admin role renounced by deployer");

        vm.stopBroadcast();

        // ── Summary ─────────────────────────────────────────────────
        console.log("--- Deployment Summary ---");
        console.log("DAOShare:", address(share));
        console.log("TimelockController:", address(timelock));
        console.log("GovernorDAO:", address(governor));
        console.log("EmergencyGovernor:", address(emergencyGovernor));
        console.log("ENSResolver:", address(resolver));
        console.log("ReleaseProposal (recorder):", address(recorder));
        console.log("Total members:", initialMembers.length);
        console.log("---");
    }

    /// @notice Parse a comma-separated string of addresses.
    /// @param raw Comma-separated hex addresses (e.g. "0x123...,0x456...")
    /// @return Array of parsed addresses
    function _parseAddresses(
        string memory raw
    ) internal pure returns (address[] memory) {
        // Count commas to determine array size
        uint256 count = 1;
        bytes memory rawBytes = bytes(raw);
        for (uint256 i = 0; i < rawBytes.length; i++) {
            if (rawBytes[i] == ",") {
                count++;
            }
        }

        address[] memory result = new address[](count);
        uint256 start = 0;
        uint256 index = 0;
        for (uint256 i = 0; i <= rawBytes.length; i++) {
            if (i == rawBytes.length || rawBytes[i] == ",") {
                bytes memory segment = new bytes(i - start);
                for (uint256 j = start; j < i; j++) {
                    segment[j - start] = rawBytes[j];
                }
                result[index] = _parseAddress(string(segment));
                index++;
                start = i + 1;
            }
        }
        return result;
    }

    /// @notice Parse a single hex string to address
    function _parseAddress(string memory hexStr) internal pure returns (address) {
        bytes memory b = bytes(hexStr);
        require(b.length == 42, "Invalid address length"); // "0x" + 40 hex chars
        uint160 addr = 0;
        for (uint256 i = 2; i < b.length; i++) {
            uint160 digit = uint160(_hexCharToUint(uint8(b[i])));
            addr = addr * 16 + digit;
        }
        return address(addr);
    }

    function _hexCharToUint(uint8 c) internal pure returns (uint8) {
        if (c >= 48 && c <= 57) return c - 48;       // 0-9
        if (c >= 65 && c <= 70) return c - 55;       // A-F
        if (c >= 97 && c <= 102) return c - 87;      // a-f
        revert("Invalid hex character");
    }
}
