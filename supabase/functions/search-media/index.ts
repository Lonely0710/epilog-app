import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import * as cheerio from "https://esm.sh/cheerio@1.0.0-rc.12";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// ============================================================================
// Type Definitions
// ============================================================================

interface MediaItem {
    sourceType: string; // 'tmdb' | 'bgm' | 'maoyan' | 'douban'
    sourceId: string;
    sourceUrl: string;
    mediaType: string; // 'movie' | 'tv' | 'anime'
    titleZh: string;
    titleOriginal: string;
    releaseDate: string;
    duration: string;
    year: string;
    posterUrl: string;
    summary: string;
    staff: string;
    directors: string[];
    actors: string[];
    rating: number;
    ratingDouban: number;
    ratingImdb: number;
    ratingBangumi: number;
    ratingMaoyan: number;
    genres: string[];
    wish: string;
    isNew: boolean;
    matchCount?: number;
}

interface SearchRequest {
    query: string;
    type: "all" | "anime" | "movie";
}

// ============================================================================
// TMDb Search
// ============================================================================

async function searchTmdb(query: string): Promise<MediaItem[]> {
    const tmdbToken = Deno.env.get("TMDB_ACCESS_TOKEN");
    if (!tmdbToken) {
        console.error("TMDB_ACCESS_TOKEN not set");
        return [];
    }

    try {
        const searchParams = new URLSearchParams({
            query: query,
            language: "zh-CN",
            include_adult: "false",
        });

        const searchUrl = `https://api.themoviedb.org/3/search/multi?${searchParams}`;
        const response = await fetch(searchUrl, {
            headers: {
                Authorization: `Bearer ${tmdbToken}`,
                "Content-Type": "application/json",
            },
        });

        if (!response.ok) {
            console.error(`TMDb search failed: ${response.status}`);
            return [];
        }

        const data = await response.json();
        const results = data.results || [];

        // Filter for movie and tv only, limit to 8
        const filtered = results
            .filter(
                (item: any) => item.media_type === "movie" || item.media_type === "tv"
            )
            .slice(0, 8);

        // Fetch details for each item in parallel
        const detailedItems = await Promise.all(
            filtered.map((item: any) => fetchTmdbDetails(item, tmdbToken))
        );

        return detailedItems.filter((item): item is MediaItem => item !== null);
    } catch (e) {
        console.error("TMDb search error:", e);
        return [];
    }
}

async function fetchTmdbDetails(
    item: any,
    token: string
): Promise<MediaItem | null> {
    try {
        const mediaType = item.media_type;
        const id = item.id;

        const detailUrl = `https://api.themoviedb.org/3/${mediaType}/${id}?language=zh-CN&append_to_response=credits`;
        const response = await fetch(detailUrl, {
            headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
            },
        });

        if (!response.ok) {
            // Fallback to basic info
            return tmdbItemToMedia(item, mediaType);
        }

        const detail = await response.json();
        return tmdbItemToMedia(detail, mediaType);
    } catch (e) {
        console.error(`TMDb detail fetch error for ${item.id}:`, e);
        return tmdbItemToMedia(item, item.media_type);
    }
}

function tmdbItemToMedia(item: any, mediaType: string): MediaItem {
    const isMovie = mediaType === "movie";
    const id = item.id?.toString() || "";
    const titleZh = isMovie ? item.title : item.name;
    const titleOriginal = isMovie ? item.original_title : item.original_name;
    const releaseDate = isMovie
        ? item.release_date || "未知日期"
        : item.first_air_date || "未知日期";

    let year = "----";
    if (releaseDate && releaseDate !== "未知日期" && releaseDate.length >= 4) {
        year = releaseDate.substring(0, 4);
    }

    const posterPath = item.poster_path;
    const posterUrl = posterPath
        ? `https://image.tmdb.org/t/p/w500${posterPath}`
        : "";
    const rating = item.vote_average || 0;

    // Duration
    let duration = "未知";
    if (isMovie && item.runtime) {
        duration = `${item.runtime}分钟`;
    } else if (!isMovie) {
        if (item.number_of_episodes) {
            duration = `共${item.number_of_episodes}集`;
        } else if (item.episode_run_time?.length) {
            duration = `${item.episode_run_time[0]}分钟/集`;
        }
    }

    // Staff
    let directors: string[] = [];
    let actors: string[] = [];

    if (item.credits) {
        const crew = item.credits.crew || [];
        directors = crew
            .filter((m: any) => m.job === "Director")
            .map((m: any) => m.name)
            .slice(0, 3);

        const cast = item.credits.cast || [];
        actors = cast.map((m: any) => m.name).slice(0, 5);

        if (!isMovie && item.created_by) {
            directors.push(...item.created_by.map((c: any) => c.name));
        }
    }

    const summary = item.overview || "暂无简介";

    return {
        sourceType: "tmdb",
        sourceId: id,
        sourceUrl: `https://www.themoviedb.org/${mediaType}/${id}`,
        mediaType: mediaType,
        titleZh: titleZh || "未知标题",
        titleOriginal: titleOriginal || "",
        releaseDate: releaseDate,
        duration: duration,
        year: year,
        posterUrl: posterUrl,
        summary: summary,
        staff: "",
        directors: directors,
        actors: actors,
        rating: rating,
        ratingDouban: 0,
        ratingImdb: rating,
        ratingBangumi: 0,
        ratingMaoyan: 0,
        genres: item.genres?.map((g: any) => g.name) || [],
        wish: "",
        isNew: false,
        matchCount: 1,
    };
}

// ============================================================================
// Bangumi Search (Web Scraping)
// ============================================================================

async function searchBangumi(query: string): Promise<MediaItem[]> {
    try {
        const encodedQuery = encodeURIComponent(query);
        const url = `https://bgm.tv/subject_search/${encodedQuery}?cat=2`;

        const response = await fetch(url, {
            headers: {
                "User-Agent":
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                Cookie: "chii_searchDateLine=0",
            },
        });

        if (!response.ok) {
            console.error(`Bangumi search failed: ${response.status}`);
            return [];
        }

        const html = await response.text();
        const $ = cheerio.load(html);
        const items: any[] = [];

        $("#browserItemList > li").each((_: number, element: any) => {
            items.push(element);
        });

        // Process items in parallel (limit to 10 for performance)
        const limitedItems = items.slice(0, 10);
        const results = await Promise.all(
            limitedItems.map((item) => parseBangumiItem($, item))
        );

        return results.filter((item): item is MediaItem => item !== null);
    } catch (e) {
        console.error("Bangumi search error:", e);
        return [];
    }
}

async function parseBangumiItem(
    $: cheerio.CheerioAPI,
    element: any
): Promise<MediaItem | null> {
    try {
        const $item = $(element);
        const titleElement = $item.find("h3 > a.l");
        if (!titleElement.length) return null;

        const href = titleElement.attr("href") || "";
        const sourceId = href.split("/").pop() || "";
        if (!sourceId) return null;

        const titleZh = titleElement.text().trim() || "未知标题";
        const titleOriginal = $item.find("h3 > small.grey").text().trim() || "";

        // Poster
        let posterUrl = "";
        const imgElement = $item.find(".subjectCover img");
        if (imgElement.length) {
            let src = imgElement.attr("src") || "";
            if (src.startsWith("//")) src = `https:${src}`;
            posterUrl = src.replace(/\/s\/|\/m\//, "/l/");
        }

        // Info text (contains date, episodes, staff)
        const infoText = $item.find(".info.tip").text().trim() || "";

        // Rating
        let rating = 0;
        const ratingElement = $item.find(".rateInfo small.fade");
        if (ratingElement.length) {
            rating = parseFloat(ratingElement.text()) || 0;
        }

        // Fetch detail for summary and duration
        let summary = "暂无简介";
        let durationDetail = "";

        try {
            const detailData = await fetchBangumiDetail(sourceId);
            if (detailData.summary) summary = detailData.summary;
            if (detailData.duration) durationDetail = detailData.duration;
        } catch (e) {
            // Continue without detail
        }

        // Parse info text
        const { releaseDate, year, duration, staff } = parseInfoText(
            infoText,
            durationDetail
        );

        return {
            sourceType: "bgm",
            sourceId: sourceId,
            sourceUrl: `https://bgm.tv/subject/${sourceId}`,
            mediaType: "anime",
            titleZh: titleZh,
            titleOriginal: titleOriginal,
            releaseDate: releaseDate,
            duration: duration,
            year: year,
            posterUrl: posterUrl,
            summary: summary,
            staff: staff || "暂无制作信息",
            directors: [],
            actors: [],
            rating: rating,
            ratingDouban: 0,
            ratingImdb: 0,
            ratingBangumi: rating,
            ratingMaoyan: 0,
            genres: [],
            wish: "",
            isNew: false,
            matchCount: 1,
        };
    } catch (e) {
        console.error("Error parsing Bangumi item:", e);
        return null;
    }
}

async function fetchBangumiDetail(
    sourceId: string
): Promise<{ summary?: string; duration?: string }> {
    const url = `https://bgm.tv/subject/${sourceId}`;
    const response = await fetch(url, {
        headers: {
            "User-Agent":
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            Cookie: "chii_searchDateLine=0",
        },
    });

    if (!response.ok) return {};

    const html = await response.text();
    const $ = cheerio.load(html);

    const result: { summary?: string; duration?: string } = {};

    // Summary
    const summaryEl = $("#subject_summary");
    if (summaryEl.length) {
        let text = summaryEl.text();
        text = text.replace(/\u00A0/g, "\n");
        text = text.replace(/\s{4,}/g, "\n");
        result.summary = text.trim();
    }

    // Duration (episodes)
    $("#infobox li").each((_: number, el: any) => {
        const text = $(el).text();
        if (text.includes("话数:")) {
            let episodes = text.replace("话数:", "").trim();
            if (/^\d+$/.test(episodes)) {
                episodes += "集";
            }
            result.duration = episodes;
        }
    });

    return result;
}

function parseInfoText(
    infoText: string,
    durationDetail: string
): { releaseDate: string; year: string; duration: string; staff: string } {
    const parts = infoText.split(" / ");
    let releaseDate = "";
    let year = "";
    let duration = "";
    let staff = "";

    for (const part of parts) {
        const trimmed = part.trim();

        // Date pattern
        const fullDateMatch = trimmed.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/);
        const monthMatch = trimmed.match(/(\d{4})年(\d{1,2})月/);
        const yearMatch = trimmed.match(/(\d{4})年/);

        if (fullDateMatch) {
            const [, y, m, d] = fullDateMatch;
            releaseDate = `${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`;
            year = y;
        } else if (monthMatch) {
            const [, y, m] = monthMatch;
            releaseDate = `${y}-${m.padStart(2, "0")}-01`;
            year = y;
        } else if (yearMatch) {
            year = yearMatch[1];
            releaseDate = `${year}-01-01`;
        } else if (/\d+话/.test(trimmed)) {
            duration = trimmed;
        } else {
            if (staff) staff += " / ";
            staff += trimmed;
        }
    }

    // Override with detail if available
    if (durationDetail) duration = durationDetail;
    if (!duration) duration = "未知";
    if (!releaseDate) releaseDate = "未知日期";
    if (!year) year = "----";

    return { releaseDate, year, duration, staff };
}

// ============================================================================
// Maoyan Search
// ============================================================================

async function searchMaoyan(query: string): Promise<MediaItem[]> {
    try {
        const url = `https://m.maoyan.com/ajax/search?kw=${encodeURIComponent(
            query
        )}&cityId=1&stype=-1`;

        const response = await fetch(url, {
            headers: {
                "User-Agent":
                    "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1",
            },
        });

        if (!response.ok) {
            console.error(`Maoyan search failed: ${response.status}`);
            return [];
        }

        const data = await response.json();
        const results: MediaItem[] = [];

        if (data?.movies?.list) {
            for (const item of data.movies.list.slice(0, 8)) {
                try {
                    const media = maoyanItemToMedia(item);
                    results.push(media);
                } catch (e) {
                    console.error("Error parsing Maoyan item:", e);
                }
            }
        }

        return results;
    } catch (e) {
        console.error("Maoyan search error:", e);
        return [];
    }
}

function maoyanItemToMedia(item: any): MediaItem {
    const id = item.id?.toString() || "";
    const title = item.nm || "未知标题";
    const originalTitle = item.enm || "";
    const score = parseFloat(item.sc) || 0;
    const wish = item.wish?.toString() || "0";

    // Poster
    let poster = item.img || "";
    if (poster.includes("/w.h/")) {
        poster = poster.replace("/w.h/", "/");
    }

    const pubDesc = item.pubDesc || "";
    const releaseDate = item.rt || "";

    let year = "----";
    if (releaseDate && releaseDate.length >= 4) {
        year = releaseDate.substring(0, 4);
    } else if (pubDesc) {
        const yearMatch = pubDesc.match(/\d{4}/);
        if (yearMatch) year = yearMatch[0];
    }

    const director = item.dir || "";
    const actorsStr = item.star || "";
    const genresStr = item.cat || "";
    const dur = item.dur || 0;

    const isNew =
        item.showStateButton?.content === "购票" ||
        item.showStateButton?.content === "预售";

    let staff = "";
    if (director) staff += `导演: ${director} `;
    if (actorsStr) staff += `主演: ${actorsStr}`;

    const genres = genresStr
        .split(",")
        .map((s: string) => s.trim())
        .filter((s: string) => s);
    const actors = actorsStr
        .split(",")
        .map((s: string) => s.trim())
        .filter((s: string) => s);

    return {
        sourceType: "maoyan",
        sourceId: id,
        sourceUrl: `https://m.maoyan.com/movie/${id}`,
        mediaType: "movie",
        titleZh: title,
        titleOriginal: originalTitle,
        releaseDate: releaseDate,
        duration: dur ? `${dur}分钟` : "未知",
        year: year,
        posterUrl: poster,
        summary: "暂无简介",
        staff: staff || "暂无制作信息",
        directors: director ? [director] : [],
        actors: actors,
        rating: score,
        ratingDouban: 0,
        ratingImdb: 0,
        ratingBangumi: 0,
        ratingMaoyan: score,
        genres: genres,
        wish: wish,
        isNew: isNew,
        matchCount: 1,
    };
}

// ============================================================================
// Douban Search (Web Scraping)
// ============================================================================

async function searchDouban(query: string): Promise<MediaItem[]> {
    try {
        const url = `https://www.douban.com/search?cat=1002&q=${encodeURIComponent(
            query
        )}`;

        const response = await fetch(url, {
            headers: {
                "User-Agent":
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                Accept:
                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            },
        });

        if (!response.ok) {
            console.error(`Douban search failed: ${response.status}`);
            return [];
        }

        const html = await response.text();
        const $ = cheerio.load(html);
        const results: MediaItem[] = [];

        $(".result-list .result")
            .slice(0, 8)
            .each((_: number, element: any) => {
                try {
                    const $item = $(element);

                    // Get ID from onclick
                    const titleLink = $item.find("h3 a");
                    const onclick = titleLink.attr("onclick") || "";
                    const idMatch = onclick.match(/sid:\s*(\d+)/);
                    if (!idMatch) return;
                    const sourceId = idMatch[1];

                    // Title
                    const titleZh = titleLink.text().trim() || "未知标题";

                    // Rating
                    let rating = 0;
                    const ratingEl = $item.find(".rating_nums");
                    if (ratingEl.length) {
                        rating = parseFloat(ratingEl.text()) || 0;
                    }

                    // Subject cast (contains year, staff info)
                    const subjectCast = $item.find(".subject-cast");
                    let staffStr = "";
                    let year = "----";

                    if (subjectCast.length) {
                        const text = subjectCast.text().trim();
                        const yearMatch = text.match(/\d{4}/);
                        if (yearMatch) year = yearMatch[0];
                        staffStr = text.replace(/原名:.*?(?:\/|$)/, "").trim();
                        if (staffStr.startsWith("/")) staffStr = staffStr.substring(1).trim();
                    }

                    results.push({
                        sourceType: "douban",
                        sourceId: sourceId,
                        sourceUrl: `https://movie.douban.com/subject/${sourceId}`,
                        mediaType: "movie",
                        titleZh: titleZh,
                        titleOriginal: "",
                        releaseDate: "未知日期",
                        duration: "未知",
                        year: year,
                        posterUrl: "", // Would need detail fetch
                        summary: "暂无简介",
                        staff: staffStr || "暂无制作信息",
                        directors: [],
                        actors: [],
                        rating: rating,
                        ratingDouban: rating,
                        ratingImdb: 0,
                        ratingBangumi: 0,
                        ratingMaoyan: 0,
                        genres: [],
                        wish: "",
                        isNew: false,
                        matchCount: 1,
                    });
                } catch (e) {
                    console.error("Error parsing Douban item:", e);
                }
            });

        return results;
    } catch (e) {
        console.error("Douban search error:", e);
        return [];
    }
}

// ============================================================================
// Result Merging & Deduplication
// ============================================================================

/**
 * Normalize a title for comparison
 * Removes spaces, punctuation, and converts to lowercase
 */
function normalizeTitle(title: string): string {
    if (!title) return "";
    return title
        .toLowerCase()
        .replace(/\s+/g, "")
        // Remove common punctuation and special chars
        .replace(/[。、，！？：；""''「」『』【】（）\[\]().,!?:;'"－—·～~]/g, "")
        // Remove all non-word chars except Chinese characters
        .replace(/[^\w\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff]/g, "")
        .trim();
}

/**
 * Check if two titles are similar enough to be considered the same
 */
function areTitlesSimilar(title1: string, title2: string): boolean {
    const norm1 = normalizeTitle(title1);
    const norm2 = normalizeTitle(title2);

    if (!norm1 || !norm2) return false;

    // Exact match after normalization
    if (norm1 === norm2) return true;

    // One contains the other (for titles with subtitles)
    if (norm1.includes(norm2) || norm2.includes(norm1)) {
        // Only if the shorter one is at least 2 characters
        const shorter = norm1.length < norm2.length ? norm1 : norm2;
        if (shorter.length >= 2) return true;
    }

    return false;
}

/**
 * Check if two years are close enough (within 1 year, accounting for release differences)
 */
function areYearsSimilar(year1: string, year2: string): boolean {
    if (!year1 || !year2 || year1 === "----" || year2 === "----") return true; // Unknown years don't disqualify

    const y1 = parseInt(year1);
    const y2 = parseInt(year2);

    if (isNaN(y1) || isNaN(y2)) return true;

    return Math.abs(y1 - y2) <= 1;
}

/**
 * Calculate data completeness score for an item
 * Higher score = more complete data, should be preferred
 */
function calculateCompletenessScore(item: MediaItem): number {
    let score = 0;

    // Has poster
    if (item.posterUrl && item.posterUrl.length > 0) score += 20;

    // Has summary (not placeholder)
    if (item.summary && item.summary !== "暂无简介" && item.summary.length > 10) score += 15;

    // Has ratings (each rating adds value)
    if (item.ratingImdb > 0) score += 10;
    if (item.ratingDouban > 0) score += 10;
    if (item.ratingBangumi > 0) score += 10;
    if (item.ratingMaoyan > 0) score += 8;

    // Has directors/actors info
    if (item.directors && item.directors.length > 0) score += 8;
    if (item.actors && item.actors.length > 0) score += 8;

    // Has genres
    if (item.genres && item.genres.length > 0) score += 5;

    // Has duration (not unknown)
    if (item.duration && item.duration !== "未知") score += 5;

    // Has original title
    if (item.titleOriginal && item.titleOriginal.length > 0) score += 5;

    // Source priority: TMDb > Bangumi > Maoyan > Douban (for data quality)
    if (item.sourceType === "tmdb") score += 10;
    else if (item.sourceType === "bgm") score += 8;
    else if (item.sourceType === "maoyan") score += 5;
    else if (item.sourceType === "douban") score += 3;

    return score;
}

/**
 * Merge two MediaItems, keeping the most complete data
 */
function mergeItems(primary: MediaItem, secondary: MediaItem): MediaItem {
    const merged = { ...primary };

    // Merge match count
    merged.matchCount = (primary.matchCount || 1) + (secondary.matchCount || 1);

    // Merge ratings (take non-zero values)
    if (secondary.ratingImdb > 0 && merged.ratingImdb === 0) {
        merged.ratingImdb = secondary.ratingImdb;
    }
    if (secondary.ratingDouban > 0 && merged.ratingDouban === 0) {
        merged.ratingDouban = secondary.ratingDouban;
    }
    if (secondary.ratingBangumi > 0 && merged.ratingBangumi === 0) {
        merged.ratingBangumi = secondary.ratingBangumi;
    }
    if (secondary.ratingMaoyan > 0 && merged.ratingMaoyan === 0) {
        merged.ratingMaoyan = secondary.ratingMaoyan;
    }

    // Use secondary's poster if primary doesn't have one
    if ((!merged.posterUrl || merged.posterUrl.length === 0) && secondary.posterUrl) {
        merged.posterUrl = secondary.posterUrl;
    }

    // Use secondary's summary if primary's is placeholder
    if ((merged.summary === "暂无简介" || !merged.summary) && secondary.summary && secondary.summary !== "暂无简介") {
        merged.summary = secondary.summary;
    }

    // Use secondary's directors/actors if primary doesn't have
    if ((!merged.directors || merged.directors.length === 0) && secondary.directors && secondary.directors.length > 0) {
        merged.directors = secondary.directors;
    }
    if ((!merged.actors || merged.actors.length === 0) && secondary.actors && secondary.actors.length > 0) {
        merged.actors = secondary.actors;
    }

    // Use secondary's genres if primary doesn't have
    if ((!merged.genres || merged.genres.length === 0) && secondary.genres && secondary.genres.length > 0) {
        merged.genres = secondary.genres;
    }

    // Use secondary's duration if primary is unknown
    if ((merged.duration === "未知" || !merged.duration) && secondary.duration && secondary.duration !== "未知") {
        merged.duration = secondary.duration;
    }

    // Use secondary's original title if primary doesn't have
    if ((!merged.titleOriginal || merged.titleOriginal.length === 0) && secondary.titleOriginal) {
        merged.titleOriginal = secondary.titleOriginal;
    }

    return merged;
}

/**
 * Check if two items represent the same media
 */
function areSameMedia(item1: MediaItem, item2: MediaItem): boolean {
    // Must have similar years
    if (!areYearsSimilar(item1.year, item2.year)) return false;

    // Check Chinese titles
    if (areTitlesSimilar(item1.titleZh, item2.titleZh)) return true;

    // Check original titles
    if (item1.titleOriginal && item2.titleOriginal) {
        if (areTitlesSimilar(item1.titleOriginal, item2.titleOriginal)) return true;
    }

    // Cross-check: Chinese title vs Original title
    if (areTitlesSimilar(item1.titleZh, item2.titleOriginal)) return true;
    if (areTitlesSimilar(item1.titleOriginal, item2.titleZh)) return true;

    return false;
}

function deduplicateResults(allResults: MediaItem[]): MediaItem[] {
    if (allResults.length === 0) return [];

    // Sort by completeness score descending (most complete first)
    const sortedResults = [...allResults].sort((a, b) => {
        return calculateCompletenessScore(b) - calculateCompletenessScore(a);
    });

    const uniqueResults: MediaItem[] = [];

    for (const result of sortedResults) {
        // Find if there's an existing item that matches
        const existingIndex = uniqueResults.findIndex(existing => areSameMedia(existing, result));

        if (existingIndex === -1) {
            // No match found, add as new unique result
            uniqueResults.push(result);
        } else {
            // Match found, merge the data
            uniqueResults[existingIndex] = mergeItems(uniqueResults[existingIndex], result);
        }
    }

    return uniqueResults;
}

// ============================================================================
// Relevance Scoring & Filtering
// ============================================================================

/**
 * Calculate relevance score for a search result
 * Higher score = more relevant
 */
function calculateRelevanceScore(item: MediaItem, query: string): number {
    const normalizedQuery = query.toLowerCase().trim();
    const normalizedTitleZh = (item.titleZh || "").toLowerCase().trim();
    const normalizedTitleOriginal = (item.titleOriginal || "").toLowerCase().trim();

    let score = 0;

    // Boost for multi-source matches (highest priority)
    // If an item is found in multiple sources, it's very likely the correct one
    if (item.matchCount && item.matchCount > 1) {
        score += (item.matchCount - 1) * 30; // +30 for each extra source
    }

    // Exact match (highest priority)
    if (normalizedTitleZh === normalizedQuery || normalizedTitleOriginal === normalizedQuery) {
        score += 100;
    }
    // Title starts with query
    else if (normalizedTitleZh.startsWith(normalizedQuery) || normalizedTitleOriginal.startsWith(normalizedQuery)) {
        score += 80;
    }
    // Query starts with title (partial match)
    else if (normalizedQuery.startsWith(normalizedTitleZh) || normalizedQuery.startsWith(normalizedTitleOriginal)) {
        score += 70;
    }
    // Title contains query
    else if (normalizedTitleZh.includes(normalizedQuery) || normalizedTitleOriginal.includes(normalizedQuery)) {
        score += 60;
    }
    // Check individual characters for partial matching (Chinese characters)
    else {
        let charMatchCount = 0;
        for (const char of normalizedQuery) {
            if (normalizedTitleZh.includes(char) || normalizedTitleOriginal.includes(char)) {
                charMatchCount++;
            }
        }
        const matchRatio = charMatchCount / normalizedQuery.length;
        // Only count if at least 50% of characters match
        if (matchRatio >= 0.5) {
            score += Math.floor(matchRatio * 40);
        }
    }

    // Bonus for having a rating (indicates known/popular content)
    if (item.rating > 0 || item.ratingImdb > 0 || item.ratingDouban > 0 || item.ratingMaoyan > 0 || item.ratingBangumi > 0) {
        score += 10;
    }

    // Source priority for non-anime queries (TMDb/Maoyan typically more relevant for movies/TV)
    if (item.sourceType === "tmdb") {
        score += 5;
    } else if (item.sourceType === "maoyan") {
        score += 4;
    } else if (item.sourceType === "douban") {
        score += 3;
    }
    // bgm has lower priority for general searches but higher for anime-specific

    return score;
}

function filterRelevantResults(results: MediaItem[], query?: string): MediaItem[] {
    let filtered = results.filter((item) => {
        if (!item.posterUrl) return false;
        if (!item.titleZh || item.titleZh === "未知标题") return false;
        return true;
    });

    // If query is provided, calculate relevance and sort
    if (query) {
        // Calculate relevance scores
        const scoredResults = filtered.map((item) => ({
            item,
            score: calculateRelevanceScore(item, query),
        }));

        // Filter out very low relevance results (score < 10)
        const relevantResults = scoredResults.filter((r) => r.score >= 10);

        // Sort by score descending
        relevantResults.sort((a, b) => b.score - a.score);

        // Log for debugging
        console.log(`Relevance scores for "${query}":`);
        relevantResults.slice(0, 5).forEach((r) => {
            console.log(`  ${r.item.titleZh} (${r.item.sourceType}): ${r.score}`);
        });

        filtered = relevantResults.map((r) => r.item);
    }

    return filtered;
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const { query, type }: SearchRequest = await req.json();

        if (!query || query.trim().length === 0) {
            return new Response(JSON.stringify({ error: "Query is required" }), {
                headers: { ...corsHeaders, "Content-Type": "application/json" },
                status: 400,
            });
        }

        console.log(`Searching for: "${query}" with type: ${type}`);

        let results: MediaItem[] = [];

        if (type === "anime") {
            // Anime search: Bangumi only
            results = await searchBangumi(query);
        } else if (type === "movie") {
            // Movie search: TMDb, Maoyan, Douban in parallel
            const [tmdbResults, maoyanResults, doubanResults] = await Promise.all([
                searchTmdb(query).catch((e) => {
                    console.error("TMDb error:", e);
                    return [];
                }),
                searchMaoyan(query).catch((e) => {
                    console.error("Maoyan error:", e);
                    return [];
                }),
                searchDouban(query).catch((e) => {
                    console.error("Douban error:", e);
                    return [];
                }),
            ]);

            // Priority: TMDb > Maoyan > Douban
            const allResults = [...tmdbResults, ...maoyanResults, ...doubanResults];
            results = deduplicateResults(allResults);
        } else {
            // All search: All sources in parallel
            const [bangumiResults, tmdbResults, maoyanResults, doubanResults] =
                await Promise.all([
                    searchBangumi(query).catch((e) => {
                        console.error("Bangumi error:", e);
                        return [];
                    }),
                    searchTmdb(query).catch((e) => {
                        console.error("TMDb error:", e);
                        return [];
                    }),
                    searchMaoyan(query).catch((e) => {
                        console.error("Maoyan error:", e);
                        return [];
                    }),
                    searchDouban(query).catch((e) => {
                        console.error("Douban error:", e);
                        return [];
                    }),
                ]);

            console.log(`All search results - Bangumi: ${bangumiResults.length}, TMDb: ${tmdbResults.length}, Maoyan: ${maoyanResults.length}, Douban: ${doubanResults.length}`);

            const allResults = [
                ...bangumiResults,
                ...tmdbResults,
                ...maoyanResults,
                ...doubanResults,
            ];
            console.log(`Total before dedup: ${allResults.length}`);
            results = deduplicateResults(allResults);
            console.log(`Total after dedup: ${results.length}`);
        }

        // Filter out low quality results and sort by relevance
        const filtered = filterRelevantResults(results, query);

        console.log(`Returning ${filtered.length} results after filtering (before: ${results.length})`);

        return new Response(JSON.stringify({ results: filtered }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
        });
    } catch (error: any) {
        console.error("Search error:", error);
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 500,
        });
    }
});
