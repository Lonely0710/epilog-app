import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Helpers
async function getCurrentUser(ctx: any) {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
        throw new Error("Authentication required");
    }
    return identity.tokenIdentifier;
}

// Helper to check if years match (within 1 year diff)
function isYearMatch(y1?: string, y2?: string): boolean {
    if (!y1 || !y2) return false;
    // Extract year number (simple assumption: YYYY)
    const n1 = parseInt(y1.substring(0, 4));
    const n2 = parseInt(y2.substring(0, 4));
    if (isNaN(n1) || isNaN(n2)) return false;
    return Math.abs(n1 - n2) <= 1;
}

// Helper: parse JSON string array from Flutter FFI (workaround for FFI serialization bug)
function parseJsonArray(value: string | string[] | undefined): string[] {
    if (!value) return [];
    if (Array.isArray(value)) return value;
    // If it's a JSON string, parse it
    try {
        const parsed = JSON.parse(value);
        if (Array.isArray(parsed)) return parsed;
    } catch {
        // Not valid JSON, return empty
    }
    return [];
}

// Helper: parse number that might come as string from Flutter FFI
function parseNumber(value: string | number | undefined): number | undefined {
    if (value === undefined || value === null) return undefined;
    if (typeof value === 'number') return value;
    if (typeof value === 'string') {
        const parsed = parseFloat(value);
        return isNaN(parsed) ? undefined : parsed;
    }
    return undefined;
}

export const collectMedia = mutation({
    args: {
        // Media Data
        sourceType: v.string(),
        sourceId: v.string(),
        sourceUrl: v.string(),
        mediaType: v.string(),
        titleZh: v.string(),
        titleOriginal: v.optional(v.string()),
        releaseDate: v.optional(v.string()),
        duration: v.optional(v.string()),
        year: v.optional(v.string()),
        posterUrl: v.optional(v.string()),
        summary: v.optional(v.string()),
        // Changed to string to accept JSON-encoded arrays from Flutter FFI
        staffJson: v.optional(v.string()),
        // Accept as string (JSON-encoded) due to convex_flutter FFI bug
        directorsJson: v.optional(v.string()),
        actorsJson: v.optional(v.string()),
        networksJson: v.optional(v.string()),

        // Accept ratings as union of number/string due to FFI bug
        ratingDouban: v.optional(v.union(v.number(), v.string())),
        ratingImdb: v.optional(v.union(v.number(), v.string())),
        ratingBangumi: v.optional(v.union(v.number(), v.string())),
        ratingMaoyan: v.optional(v.union(v.number(), v.string())),

        // Collection Data
        status: v.string(),
    },
    handler: async (ctx, args) => {
        const userId = await getCurrentUser(ctx);
        const now = Date.now();
        const titleZh = args.titleZh.trim() || args.titleOriginal?.trim();
        if (!titleZh) {
            throw new Error("Cannot collect media without a title");
        }
        const sourceType = args.sourceType.trim();
        const sourceId = args.sourceId.trim();
        if (!sourceType || !sourceId) {
            throw new Error("Cannot collect media without a source");
        }

        // Parse JSON string arrays from Flutter FFI
        const actors = parseJsonArray(args.actorsJson);
        const directors = parseJsonArray(args.directorsJson);

        // Parse networks JSON [{name, logoUrl}]
        let networks: Array<{name: string; logoUrl: string}> = [];
        if (args.networksJson) {
            try {
                const parsed = JSON.parse(args.networksJson);
                if (Array.isArray(parsed)) {
                    networks = parsed.map((n: any) => ({
                        name: n.name || '',
                        logoUrl: n.logoUrl || '',
                    })).filter((n: any) => n.name);
                }
            } catch {
                networks = [];
            }
        }


        // Parse staff JSON if provided
        let staff: { info?: string; actors?: string[]; directors?: string[] } | undefined;
        if (args.staffJson) {
            try {
                const parsed = JSON.parse(args.staffJson);
                staff = {
                    info: parsed.info,
                    actors: parseJsonArray(parsed.actors),
                    directors: parseJsonArray(parsed.directors),
                };
            } catch {
                staff = undefined;
            }
        }

        // -----------------------------------------------------
        // Step 1: Check by Source ID (Exact Match)
        // -----------------------------------------------------
        let mediaId;

        const existingSource = await ctx.db
            .query("media_sources")
            .withIndex("by_source", (q) =>
                q.eq("sourceType", sourceType).eq("sourceId", sourceId)
            )
            .first();

        if (existingSource) {
            mediaId = existingSource.mediaId;
        } else {
            // -----------------------------------------------------
            // Step 2: Check by Content (Fuzzy Match / Deduplication)
            // -----------------------------------------------------
            // Strategy: 
            // 1. Try matching TitleZH + MediaType
            // 2. Try matching TitleOriginal + MediaType (if TitleOriginal exists)
            // 3. For both candidates, verify Year (if available)

            let candidateMedia = await ctx.db
                .query("media")
                .withIndex("by_type_title_zh", (q) =>
                    q.eq("mediaType", args.mediaType).eq("titleZh", titleZh)
                )
                .first();

            // If not found by Chinese title, and we have an original title, try that
            if (!candidateMedia && args.titleOriginal) {
                candidateMedia = await ctx.db
                    .query("media")
                    .withIndex("by_type_title_original", (q) =>
                        q.eq("mediaType", args.mediaType).eq("titleOriginal", args.titleOriginal!)
                    )
                    .first();
            }

            // Verify Year if candidate found
            let isMatch = false;
            if (candidateMedia) {
                // strict year check if both have years
                if (args.year && candidateMedia.year) {
                    if (isYearMatch(args.year, candidateMedia.year)) {
                        isMatch = true;
                    }
                } else {
                    isMatch = true;
                }
            }

            if (candidateMedia && isMatch) {
                mediaId = candidateMedia._id;
                // Found media, but valid source mapping missing.
                // Insert new Source Mapping
                await ctx.db.insert("media_sources", {
                    mediaId,
                    sourceType,
                    sourceId,
                    sourceUrl: args.sourceUrl,
                });

                // -----------------------------------------------------
                // Priority: Update staff from BGM for anime
                // -----------------------------------------------------
                if (args.sourceType === 'bgm' && args.mediaType === 'anime' && staff && staff.info) {
                    await ctx.db.patch(mediaId, {
                        staff: staff,
                    });
                }
            } else {
                // -----------------------------------------------------
                // Step 3: Create New Media & Source
                // -----------------------------------------------------
                mediaId = await ctx.db.insert("media", {
                    mediaType: args.mediaType,
                    titleZh,
                    titleOriginal: args.titleOriginal,
                    releaseDate: args.releaseDate,
                    duration: args.duration,
                    year: args.year,
                    posterUrl: args.posterUrl,
                    summary: args.summary,
                    staff: staff,
                    directors: directors,
                    actors: actors,
                    networks: networks,

                    // Compute rating from available source ratings (parse strings to numbers)
                    rating: parseNumber(args.ratingDouban) ?? parseNumber(args.ratingImdb) ?? parseNumber(args.ratingBangumi) ?? parseNumber(args.ratingMaoyan) ?? 0,
                    ratingDouban: parseNumber(args.ratingDouban),
                    ratingImdb: parseNumber(args.ratingImdb),
                    ratingBangumi: parseNumber(args.ratingBangumi),
                    ratingMaoyan: parseNumber(args.ratingMaoyan),
                });

                await ctx.db.insert("media_sources", {
                    mediaId,
                    sourceType,
                    sourceId,
                    sourceUrl: args.sourceUrl,
                });
            }
        }

        // -----------------------------------------------------
        // Step 4: Upsert Collection
        // -----------------------------------------------------
        const existingCollection = await ctx.db
            .query("collections")
            .withIndex("by_user_media", (q) =>
                q.eq("userId", userId).eq("mediaId", mediaId!)
            )
            .first();

        if (existingCollection) {
            await ctx.db.patch(existingCollection._id, {
                status: args.status,
                updatedAt: now,
            });
            return {
                collectionId: existingCollection._id,
                status: args.status,
            };
        } else {
            const id = await ctx.db.insert("collections", {
                userId,
                mediaId: mediaId!,
                status: args.status,
                createdAt: now,
                updatedAt: now,
            });
            return {
                collectionId: id,
                status: args.status,
            };
        }
    },
});

export const removeCollection = mutation({
    args: { collectionId: v.id("collections") },
    handler: async (ctx, args) => {
        const userId = await getCurrentUser(ctx);
        const item = await ctx.db.get(args.collectionId);

        if (!item || item.userId !== userId) {
            throw new Error("Collection not found or access denied");
        }

        await ctx.db.delete(args.collectionId);
    },
});

export const updateWatchStatus = mutation({
    args: {
        collectionId: v.id("collections"),
        status: v.string(),
    },
    handler: async (ctx, args) => {
        const userId = await getCurrentUser(ctx);
        const item = await ctx.db.get(args.collectionId);

        if (!item || item.userId !== userId) {
            throw new Error("Collection not found or access denied");
        }

        // Validate status
        const validStatuses = ["wish", "watching", "watched", "on_hold", "dropped"];
        if (!validStatuses.includes(args.status)) {
            throw new Error(`Invalid status: ${args.status}. Must be one of: ${validStatuses.join(", ")}`);
        }

        await ctx.db.patch(args.collectionId, {
            status: args.status,
            updatedAt: Date.now(),
        });

        return { success: true, status: args.status };
    },
});

export const checkCollectionStatus = query({
    args: { sourceType: v.string(), sourceId: v.string() },
    handler: async (ctx, args) => {
        const userId = await getCurrentUser(ctx);

        // 1. Find Source
        const source = await ctx.db
            .query("media_sources")
            .withIndex("by_source", (q) =>
                q.eq("sourceType", args.sourceType).eq("sourceId", args.sourceId)
            )
            .first();

        if (!source) return null;

        // 2. Find collection by Media ID
        const collection = await ctx.db
            .query("collections")
            .withIndex("by_user_media", (q) =>
                q.eq("userId", userId).eq("mediaId", source.mediaId)
            )
            .first();

        if (!collection) return null;

        return {
            collectionId: collection._id,
            status: collection.status,
        };
    },
});

export const getUserCollections = query({
    args: {
        status: v.optional(v.string()),
        _ts: v.optional(v.string()), // Cache buster
    },
    handler: async (ctx, args) => {
        const userId = await getCurrentUser(ctx);

        let query = ctx.db
            .query("collections")
            .withIndex("by_user_created", (q) => q.eq("userId", userId))
            .order("desc");

        let collections = await query.collect();

        if (args.status) {
            collections = collections.filter(c => c.status === args.status);
        }

        // Join with Media
        const results = await Promise.all(
            collections.map(async (c) => {
                const media = await ctx.db.get(c.mediaId);
                if (!media) return null;
                if (!media.titleZh && !media.titleOriginal) return null;

                // Prioritize finding a source link using the efficient index
                // For anime: prefer bgm source; For movie/tv: prefer tmdb source
                const allSources = await ctx.db
                    .query("media_sources")
                    .withIndex("by_media", (q) => q.eq("mediaId", media._id))
                    .collect();

                let source = allSources[0]; // default to first
                if (allSources.length > 1) {
                    if (media.mediaType === "anime") {
                        // Prefer Bangumi for anime
                        const bgmSource = allSources.find(s => s.sourceType === "bgm");
                        if (bgmSource) source = bgmSource;
                    } else {
                        // Prefer TMDB for movie/tv
                        const tmdbSource = allSources.find(s => s.sourceType === "tmdb");
                        if (tmdbSource) source = tmdbSource;
                    }
                }

                // If no source found (shouldn't happen), use empty
                const sId = source ? source.sourceId : "";
                const sType = source ? source.sourceType : "";
                const sUrl = source ? source.sourceUrl : "";

                return {
                    ...media,
                    sourceId: sId,
                    sourceType: sType,
                    sourceUrl: sUrl,
                    collectionId: c._id,
                    watchingStatus: c.status,
                    collectedAt: c.createdAt,
                    isCollected: true,
                };
            })
        );

        return results.filter(r => r !== null);
    },
});
