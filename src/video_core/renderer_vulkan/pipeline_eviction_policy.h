// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <algorithm>
#include <cstddef>
#include <numeric>
#include <span>
#include <vector>

#include "common/common_types.h"

namespace Vulkan {

/// Built graphics pipelines kept on desktop before unused ones are destroyed. Destroying them
/// sooner costs far more than the 2-3 ms per rebuild once assumed: an 80-minute Ocarina of Time
/// session evicted 8,567 and rebuilt 8,158 of them on the GPU thread (35.5 s of builds, 66.7 s of
/// draws held), while no more than ~2,000 were alive at once.
inline constexpr size_t DefaultKeptPipelines = 4096;

/// Host memory one built graphics pipeline holds, rounded up: building OoT's 12,900 cached
/// pipelines at boot added 3.4 GiB of committed memory (~0.27 MiB each, NVIDIA).
inline constexpr u64 PipelineBytes = 300 * 1024;

/// The automatic limit on a machine with `total_memory` bytes of RAM: as many built pipelines as
/// fit in a quarter of it (8 GiB: 6,990; 32 GiB: 27,962). It doesn't follow the disk cache's size:
/// after the cache is cleared a session builds thousands of new pipelines (OoT: 5,598 in 82 min
/// from 768 cached), and a limit sized to the cache loaded at boot (4,096 there) started evicting
/// them after 50 minutes. A failed memory query (`total_memory` 0) gives DefaultKeptPipelines.
constexpr size_t KeptPipelinesForMemory(u64 total_memory) {
    if (total_memory == 0) {
        return DefaultKeptPipelines;
    }
    return static_cast<size_t>(total_memory / 4 / PipelineBytes);
}

/// Picks which unused pipelines to destroy so that at most `kept` stay built.
/// @param last_uses Frame each candidate was last used (0 for a prebuilt one no draw has used).
///                  Candidates are built pipelines old enough to evict and not the current one.
/// @param built     Built graphics pipelines in the cache, candidates included.
/// @param kept      How many built pipelines to keep, non-zero (a limit of 0 is the cache's old
///                  eviction, which does not use this).
/// @return Indices into `last_uses`, least recently used first (ties in input order): only as
///         many as it takes to get back to `kept`, or every candidate when that is not enough.
inline std::vector<size_t> PipelinesToEvict(std::span<const u64> last_uses, size_t built,
                                            size_t kept) {
    if (built <= kept) {
        return {};
    }
    std::vector<size_t> order(last_uses.size());
    std::iota(order.begin(), order.end(), size_t{0});
    const size_t count = std::min(built - kept, order.size());
    std::stable_sort(order.begin(), order.end(),
                     [&](size_t a, size_t b) { return last_uses[a] < last_uses[b]; });
    order.resize(count);
    return order;
}

} // namespace Vulkan
