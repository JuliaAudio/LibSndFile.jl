# Masks

const SF_FORMAT_ENDMASK   = 0x30000000
const SF_FORMAT_TYPEMASK  = 0x0FFF0000
const SF_FORMAT_SUBMASK   = 0x0000FFFF

# Endian-ness options

const SF_ENDIAN_FILE      = 0x00000000 # Default file endian-ness.
const SF_ENDIAN_LITTLE    = 0x10000000 # Force little endian-ness.
const SF_ENDIAN_BIG       = 0x20000000 # Force big endian-ness.
const SF_ENDIAN_CPU       = 0x30000000 # Force CPU endian-ness.

# Major Formats

const SF_FORMAT_WAV       = 0x00010000 # Microsoft WAV format (little endian).
const SF_FORMAT_AIFF      = 0x00020000 # Apple/SGI AIFF format (big endian).
const SF_FORMAT_AU        = 0x00030000 # Sun/NeXT AU format (big endian).
const SF_FORMAT_RAW       = 0x00040000 # RAW PCM data.
const SF_FORMAT_PAF       = 0x00050000 # Ensoniq PARIS file format.
const SF_FORMAT_SVX       = 0x00060000 # Amiga IFF / SVX8 / SV16 format.
const SF_FORMAT_NIST      = 0x00070000 # Sphere NIST format.
const SF_FORMAT_VOC       = 0x00080000 # VOC files.
const SF_FORMAT_IRCAM     = 0x000A0000 # Berkeley/IRCAM/CARL
const SF_FORMAT_W64       = 0x000B0000 # Sonic Foundry's 64 bit RIFF/WAV
const SF_FORMAT_MAT4      = 0x000C0000 # Matlab (tm) V4.2 / GNU Octave 2.0
const SF_FORMAT_MAT5      = 0x000D0000 # Matlab (tm) V5.0 / GNU Octave 2.1
const SF_FORMAT_PVF       = 0x000E0000 # Portable Voice Format
const SF_FORMAT_XI        = 0x000F0000 # Fasttracker 2 Extended Instrument
const SF_FORMAT_HTK       = 0x00100000 # HMM Tool Kit format
const SF_FORMAT_SDS       = 0x00110000 # Midi Sample Dump Standard
const SF_FORMAT_AVR       = 0x00120000 # Audio Visual Research
const SF_FORMAT_WAVEX     = 0x00130000 # MS WAVE with WAVEFORMATEX
const SF_FORMAT_SD2       = 0x00160000 # Sound Designer 2
const SF_FORMAT_FLAC      = 0x00170000 # FLAC lossless file format
const SF_FORMAT_CAF       = 0x00180000 # Core Audio File format
const SF_FORMAT_WVE       = 0x00190000 # Psion WVE format
const SF_FORMAT_OGG       = 0x00200000 # Xiph OGG container
const SF_FORMAT_MPC2K     = 0x00210000 # Akai MPC 2000 sampler
const SF_FORMAT_RF64      = 0x00220000 # RF64 WAV file

# SubFormats

const SF_FORMAT_PCM_S8    = 0x00000001 # Signed 8 bit data
const SF_FORMAT_PCM_16    = 0x00000002 # Signed 16 bit data
const SF_FORMAT_PCM_24    = 0x00000003 # Signed 24 bit data
const SF_FORMAT_PCM_32    = 0x00000004 # Signed 32 bit data
const SF_FORMAT_PCM_U8    = 0x00000005 # Unsigned 8 bit data (WAV and RAW only)
const SF_FORMAT_FLOAT     = 0x00000006 # 32 bit float data
const SF_FORMAT_DOUBLE    = 0x00000007 # 64 bit float data
const SF_FORMAT_ULAW      = 0x00000010 # U-Law encoded.
const SF_FORMAT_ALAW      = 0x00000011 # A-Law encoded.
const SF_FORMAT_IMA_ADPCM = 0x00000012 # IMA ADPCM.
const SF_FORMAT_MS_ADPCM  = 0x00000013 # Microsoft ADPCM.
const SF_FORMAT_GSM610    = 0x00000020 # GSM 6.10 encoding.
const SF_FORMAT_VOX_ADPCM = 0x00000021 # Oki Dialogic ADPCM encoding.
const SF_FORMAT_G721_32   = 0x00000030 # 32kbs G721 ADPCM encoding.
const SF_FORMAT_G723_24   = 0x00000031 # 24kbs G723 ADPCM encoding.
const SF_FORMAT_G723_40   = 0x00000032 # 40kbs G723 ADPCM encoding.
const SF_FORMAT_DWVW_12   = 0x00000040 # 12 bit Delta Width Variable Word encoding.
const SF_FORMAT_DWVW_16   = 0x00000041 # 16 bit Delta Width Variable Word encoding.
const SF_FORMAT_DWVW_24   = 0x00000042 # 24 bit Delta Width Variable Word encoding.
const SF_FORMAT_DWVW_N    = 0x00000043 # N bit Delta Width Variable Word encoding.
const SF_FORMAT_DPCM_8    = 0x00000050 # 8 bit differential PCM (XI only)
const SF_FORMAT_DPCM_16   = 0x00000051 # 16 bit differential PCM (XI only)
const SF_FORMAT_VORBIS    = 0x00000060 # Xiph Vorbis encoding.
