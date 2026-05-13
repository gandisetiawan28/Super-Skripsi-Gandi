const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = (env, argv) => {
  const isDev = argv.mode === 'development';

  return {
    entry: {
      taskpane: './src/taskpane/index.jsx',
    },
    output: {
      path: path.resolve(__dirname, 'dist'),
      filename: '[name].bundle.js',
      clean: true,
    },
    resolve: {
      extensions: ['.js', '.jsx', '.json'],
    },
    module: {
      rules: [
        {
          test: /\.jsx?$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader',
            options: {
              presets: ['@babel/preset-env', '@babel/preset-react'],
            },
          },
        },
        {
          test: /\.css$/,
          use: ['style-loader', 'css-loader'],
        },
      ],
    },
    plugins: [
      new HtmlWebpackPlugin({
        filename: 'taskpane.html',
        template: './src/taskpane/index.html',
        chunks: ['taskpane'],
      }),
      new CopyWebpackPlugin({
        patterns: [
          { from: 'assets', to: 'assets', noErrorOnMissing: true },
          { from: 'assets/googled7a7da88e6681985.html', to: '.', noErrorOnMissing: true },
          { from: 'assets/privacy.html', to: '.', noErrorOnMissing: true },
          { from: 'assets/terms.html', to: '.', noErrorOnMissing: true },
          { from: 'assets/index.html', to: '.', noErrorOnMissing: true },
        ],
      }),
    ],
    devServer: {
      port: 3005,
      server: {
        type: 'https',
        options: {
          key: path.resolve(process.env.USERPROFILE, '.office-addin-dev-certs/localhost.key'),
          cert: path.resolve(process.env.USERPROFILE, '.office-addin-dev-certs/localhost.crt'),
        },
      },
      hot: true,
      historyApiFallback: {
        index: 'taskpane.html',
      },
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
      static: {
        directory: path.join(__dirname, 'dist'),
      },
      client: {
        overlay: true,
      },
    },
    devtool: isDev ? 'source-map' : false,
  };
};
