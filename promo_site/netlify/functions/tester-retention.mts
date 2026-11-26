import { createNetlifyTesterStore } from "../../lib/tester-endpoint";
import { purgeExpiredTesterData } from "../../lib/tester-service";

async function testerRetention() {
  await purgeExpiredTesterData(createNetlifyTesterStore());
}
export default testerRetention;

export const config = { schedule: "@hourly" };
