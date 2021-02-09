const dodoPIDs = [
  {
    token: 'ETH-USDC dodo LP (ETH)',
    pid: 0,
    lp: ''
  },
  {
    token: 'ETH-USDC dodo LP (USDC)',
    pid: 1,
    lp: '0x6B2e59b8EbE61B5ee0EF30021b7740C63F597654'
  },
  {
    token: 'LINK-USDC dodo LP (LINK) LP',
    pid: 2,
    lp: ''
  },
  {
    token: 'LINK-USDC dodo LP (USDC) LP',
    pid: 3,
    lp: ''
  },
  {
    token: 'SNX-USDC dodo LP (SNX) LP',
    pid: 6,
    lp: ''
  },
  {
    token: 'SNX-USDC dodo LP (USDC) LP',
    pid: 7,
    lp: ''
  },
  {
    token: 'COMP-USDC dodo LP (COMP) LP',
    pid: 8,
    lp: ''
  },
  {
    token: 'COMP-USDC dodo LP (USDC) LP',
    pid: 9,
    lp: ''
  },
  {
    token: 'WBTC-USDC dodo LP (WBTC) LP',
    pid: 10,
    lp: ''
  },
  {
    token: 'WBTC-USDC dodo LP (USDC) LP',
    pid: 11,
    lp: ''
  },
  {
    token: 'YFI-USDC dodo LP (YFI) LP',
    pid: 12,
    lp: ''
  },
  {
    token: 'YFI-USDC dodo LP (USDC) LP',
    pid: 13,
    lp: ''
  },
  {
    token: 'DODO',
    pid: 14,
    lp: ''
  },
]

const picklePIDs = [
  {
    token: 'PICKLE-ETH',
    pid: 0,
    lp: '0xdc98556Ce24f007A5eF6dC1CE96322d65832A819'
  },
  {
    token: 'p3CRV',
    pid: 14,
    lp: '0x1BB74b5DdC1f4fC91D6f9E7906cf68bc93538e33'
  },
  {
    token: 'pSLP-DAI',
    pid: 17,
    lp: '0x55282dA27a3a02ffe599f6D11314D239dAC89135'
  },
  {
    token: 'pSLP-USDC',
    pid: 18,
    lp: '0x8c2D16B7F6D3F989eb4878EcF13D695A7d504E43'
  },
  {
    token: 'pSLP-USDT',
    pid: 19,
    lp: '0xa7a37aE5Cb163a3147DE83F15e15D8E5f94D6bCE'
  },
  {
    token: 'pSLP-WBTC',
    pid: 20,
    lp: '0xde74b6c547bd574c3527316a2eE30cd8F6041525'
  },
  {
    token: 'pSLP-YFI',
    pid: 21,
    lp: '0x3261D9408604CC8607b687980D40135aFA26FfED'
  },
  {
    token: 'BAC-DAI',
    pid: 22,
    lp: '0x2350fc7268F3f5a6cC31f26c38f706E41547505d'
  },
  {
    token: 'pSLP-MICUSDT',
    pid: 23,
    lp: '0xC66583Dd4E25b3cfc8D881F6DbaD8288C7f5Fd30'
  },
  {
    token: 'psteCRV',
    pid: 24,
    lp: '0x77C8A58D940a322Aea02dBc8EE4A30350D4239AD'
  },
  {
    token: 'pSLP-MICUSDT',
    pid: 25,
    lp: '0x0FAA189afE8aE97dE1d2F01E471297678842146d'
  },
  {
    token: 'pSLP-yveCRV',
    pid: 26,
    lp: '0x5Eff6d166D66BacBC1BF52E2C54dD391AE6b1f48'
  }
]

const sushiPIDs = [
  {
    token: 'USDT-ETH',
    pid: 0,
    lp: '0x06da0fd433C1A5d7a4faa01111c044910A184553'
  },
  {
    token: 'USDC-ETH',
    pid: 1,
    lp: '0x397FF1542f962076d0BFE58eA045FfA2d347ACa0'
  },
  {
    token: 'DAI-ETH',
    pid: 2,
    lp: '0xC3D03e4F041Fd4cD388c549Ee2A29a9E5075882f'
  },
  {
    token: 'SUSD-ETH',
    pid: 3,
    lp: '0xF1F85b2C54a2bD284B1cf4141D64fD171Bd85539'
  },
  {
    token: 'COMP-ETH',
    pid: 4,
    lp: '0x31503dcb60119A812feE820bb7042752019F2355'
  },
  {
    token: 'LEND-ETH',
    pid: 5,
    lp: '0x5E63360E891BD60C69445970256C260b0A6A54c6'
  },
  {
    token: 'SNX-ETH',
    pid: 6,
    lp: '0xA1d7b2d891e3A1f9ef4bBC5be20630C2FEB1c470'
  },
  {
    token: 'UMA-ETH',
    pid: 7,
    lp: '0x001b6450083E531A5a7Bf310BD2c1Af4247E23D4'
  },
  {
    token: 'LINK-ETH',
    pid: 8,
    lp: '0xC40D16476380e4037e6b1A2594cAF6a6cc8Da967'
  },
  {
    token: 'BAND-ETH',
    pid: 9,
    lp: '0xA75F7c2F025f470355515482BdE9EFA8153536A8'
  },
  {
    token: 'AMPL-ETH',
    pid: 10,
    lp: '0xCb2286d9471cc185281c4f763d34A962ED212962'
  },
  {
    token: 'YFI-ETH',
    pid: 11,
    lp: '0x088ee5007C98a9677165D78dD2109AE4a3D04d0C'
  },
  {
    token: 'SUSHI-ETH',
    pid: 12,
    lp: '0x795065dCc9f64b5614C407a6EFDC400DA6221FB0'
  },
  {
    token: 'REN-ETH',
    pid: 13,
    lp: '0x611CDe65deA90918c0078ac0400A72B0D25B9bb1'
  },
  {
    token: 'CRV-ETH',
    pid: 17,
    lp: ' 0x58Dc5a51fE44589BEb22E8CE67720B5BC5378009'
  },
  {
    token: 'UNI-ETH',
    pid: 18,
    lp: '0xDafd66636E2561b0284EDdE37e42d192F2844D40'
  },
  {
    token: 'WBTC-ETH',
    pid: 21,
    lp: '0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58'
  },
  {
    token: 'CREAM-ETH',
    pid: 22,
    lp: '0xf169CeA51EB51774cF107c88309717ddA20be167'
  },
  {
    token: 'yUSD-ETH',
    pid: 25,
    lp: '0x382c4a5147Fd4090F7BE3A9Ff398F95638F5D39E'
  },
  {
    token: 'HEGIC-ETH',
    pid: 31,
    lp: '0x6463Bd6026A2E7bFab5851b62969A92f7cca0eB6'
  },
  {
    token: 'MKR-ETH',
    pid: 33,
    lp: '0xBa13afEcda9beB75De5c56BbAF696b880a5A50dD'
  },
  {
    token: 'PICKLE-ETH',
    pid: 35,
    lp: '0x269Db91Fc3c7fCC275C2E6f22e5552504512811c'
  },
  {
    token: 'OMG-ETH',
    pid: 36,
    lp: '0x742c15d71eA7444964BC39b0eD729B3729ADc361'
  },
  {
    token: 'AAVE-ETH',
    pid: 37,
    lp: '0xD75EA151a61d06868E31F8988D28DFE5E9df57B4'
  },
  {
    token: 'DPI-ETH',
    pid: 42,
    lp: '0x34b13F8CD184F55d0Bd4Dd1fe6C07D46f245c7eD'
  },
  {
    token: 'DPI-ETH',
    pid: 42,
    lp: '0x34b13F8CD184F55d0Bd4Dd1fe6C07D46f245c7eD'
  },
  {
    token: 'YAM-ETH',
    pid: 44,
    lp: '0x0F82E57804D0B1F6FAb2370A43dcFAd3c7cB239c'
  },
  {
    token: 'AKRO-ETH',
    pid: 53,
    lp: '0x364248b2f1f57C5402d244b2D469A35B4C0e9dAB'
  },
  {
    token: 'KP3R-ETH',
    pid: 58,
    lp: '0xaf988afF99d3d0cb870812C325C588D8D8CB7De8'
  },
  {
    token: 'SEEN-ETH',
    pid: 59,
    lp: '0xC5Fa164247d2F8D68804139457146eFBde8370F6'
  },
  {
    token: 'ESD-ETH',
    pid: 63,
    lp: '0xDFf71165a646BE71fCfbaa6206342FAa503AeD5D'
  },
  {
    token: 'PNK-ETH',
    pid: 65,
    lp: '0xEF4F1D5007B4FF88c1A56261fec00264AF6001Fb'
  },
  {
    token: 'BOR-ETH',
    pid: 70,
    lp: '0x44D34985826578e5ba24ec78c93bE968549BB918'
  },
  {
    token: 'WBTC-BADGER',
    pid: 73,
    lp: '0x110492b31c59716AC47337E616804E3E3AdC0b4a'
  },
  {
    token: 'INDEX-ETH',
    pid: 75,
    lp: '0xA73DF646512C82550C2b3C0324c4EEdEE53b400C'
  },
  {
    token: 'ICHI-ETH',
    pid: 79,
    lp: '0x9cD028B1287803250B1e226F0180EB725428d069'
  },
  {
    token: 'USDC-DSD',
    pid: 83,
    lp: '0x26d8151e631608570F3c28bec769C3AfEE0d73a3'
  },
  {
    token: 'TRU-ETH',
    pid: 95,
    lp: '0xfCEAAf9792139BF714a694f868A215493461446D'
  },
  {
    token: 'ALPHA-ETH',
    pid: 96,
    lp: '0xf55C33D94150d93c2cfb833bcCA30bE388b14964'
  },
  {
    token: 'ETH-CRETH2',
    pid: 98,
    lp: ' 0x71817445D11f42506F2D7F54417c935be90Ca731'
  },
  {
    token: 'COVER-ETH',
    pid: 101,
    lp: '0x66Ae32178640813F3c32a9929520BFE4Fef5D167'
  },
  {
    token: 'WBTC-DIGG',
    pid: 103,
    lp: '0x9a13867048e01c663ce8Ce2fE0cDAE69Ff9F35E3'
  },
  {
    token: 'NFTX-ETH',
    pid: 104,
    lp: '0x31d64f9403E82243e71C2af9D8F56C7DBe10C178'
  },
  {
    token: 'TUSD-ETH',
    pid: 112,
    lp: '0x760166FA4f227dA29ecAC3BeC348f5fA853a1f3C'
  },
]

const luaPIDs = [
  {
    pid: 0,
    token: 'TOMOE-ETH',
  },
  {
    pid: 1,
    token: 'TOMOE-USDT',
  },
  {
    pid: 2,
    token: 'TOMOE-USDC',
  },
  {
    pid: 3,
    token: 'LUA-USDC',
  },
  {
    token: "TOMOE-LUA",
    pid: 4
  },
  {
    token: "LUA-FRONT",
    pid: 5
  },
  {
    token: "SUSHI-LUA",
    pid: 6
  },
]

const stabilizePIDs = [
  {
    token: 'zpaUSDC',
    pid: 5,
    lp: '0x4dEaD8338cF5cb31122859b2Aec2b60416D491f0'
  },
  {
    token: 'zpaUSDT',
    pid: 6,
    lp: '0x6B2e59b8EbE61B5ee0EF30021b7740C63F597654'
  },
  {
    token: 'zpasUSD',
    pid: 7,
    lp: '0x89Cc19cece29acbD41F931F3dD61A10C1627E4c4'
  },
  {
    token: 'zpaDAI',
    pid: 8,
    lp: '0xfa8c04d342FBe24d871ea77807b1b93eC42A57ea'
  },
]

const yaxisPIDs = [
  {
    token: 'YAX-ETH',
    pid: 6,
    lp: '0x1107B6081231d7F256269aD014bF92E041cb08df'
  },
]


module.exports = {
  dodoPIDs,
  picklePIDs,
  sushiPIDs,
  luaPIDs,
  stabilizePIDs,
  yaxisPIDs
}