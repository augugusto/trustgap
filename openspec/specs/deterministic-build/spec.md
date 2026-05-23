# Deterministic Build Specification

## Purpose

A Docker-based reproducible build pipeline: the same source commit SHALL produce the identical IPFS CID for ANY two independent builders. The ceremony is manual—a member runs the pipeline locally and submits the resulting CID.

## Requirements

### Requirement: Reproducible Output

The build pipeline MUST use pinned base images, lockfiles, and deterministic tooling so that two builders on different machines produce byte-identical artifacts.

#### Scenario: Same commit, same CID

- GIVEN Builder A and Builder B both checkout the same git commit
- WHEN both run the deterministic build script
- THEN the resulting artifact CIDs SHALL be identical

#### Scenario: Pinned dependencies enforced

- GIVEN a Dockerfile with unpinned base image tag (e.g., `node:latest`)
- WHEN the build script runs
- THEN the build SHALL fail before producing output

### Requirement: CID Computation

The pipeline SHALL compute the IPFS CID of the build output directory without uploading it. The compute SHALL use the same algorithm IPFS uses (go-ipfs or kubo compatible).

#### Scenario: Local CID matches IPFS CID

- GIVEN a build output directory
- WHEN the CID is computed locally via the pipeline
- THEN it SHALL match the CID produced by an actual IPFS add of the same directory

### Requirement: Build Artifact Verification

The CLI SHALL verify the computed CID against the proposed CID stored on-chain before submitting a new release proposal. A mismatch MUST abort.

#### Scenario: CID mismatch prevents proposal

- GIVEN a computed CID that differs from the on-chain proposed CID
- WHEN the ceremony CLI attempts to submit
- THEN the submission SHALL abort with a CID mismatch error

### Requirement: Deterministic Constraints

The build MUST be fully offline-capable (no network fetches at build time). All dependencies MUST be vendored or cached in the Docker image.

#### Scenario: Offline build succeeds

- GIVEN a Docker image with all dependencies pre-cached
- WHEN the build runs with no network access
- THEN the build SHALL complete and produce the expected output
