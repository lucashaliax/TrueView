// Ponte para APIs privadas do macOS (CoreBrightness / DisplayServices).
// Tudo é carregado em tempo de execução: se a API não existir, as funções
// retornam "não suportado" em vez de travar o app.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DisplayControl : NSObject

// True Tone
+ (BOOL)trueToneSupported;
+ (BOOL)trueToneEnabled;
+ (BOOL)setTrueToneEnabled:(BOOL)enabled;

// Night Shift
+ (BOOL)nightShiftSupported;
+ (BOOL)nightShiftEnabled;
+ (BOOL)setNightShiftEnabled:(BOOL)enabled;

// Brilho da tela interna (0.0 – 1.0). Retorna -1 se não for possível ler.
+ (float)builtInBrightness;
+ (BOOL)setBuiltInBrightness:(float)value;

@end

NS_ASSUME_NONNULL_END
