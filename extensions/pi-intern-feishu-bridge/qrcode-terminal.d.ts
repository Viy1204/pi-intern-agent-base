/** qrcode-terminal 没有官方类型定义，只声明我们实际用到的那一个函数。 */
declare module "qrcode-terminal" {
  export function generate(
    text: string,
    options?: { small?: boolean },
    callback?: (qr: string) => void,
  ): void;
}
